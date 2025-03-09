require 'asciidoctor-pdf' unless Asciidoctor::Converter.for 'pdf'
require 'open3'
require 'tempfile'
require 'rexml/document'
require 'ttfunk'
require 'asciimath'

POINTS_PER_EX = 6
MATHJAX_DEFAULT_COLOR_STRING = "currentColor"

FALLBACK_FONT_SIZE = 12
FALLBACK_FONT_STYLE = 'normal'
FALLBACK_FONT_FAMILY = 'Arial'
FALLBACK_FONT_COLOR = '#000000'

class AsciidoctorPDFExtensions < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  @tempfiles = []
  class << self
    attr_reader :tempfiles
  end

  def convert_stem node
    arrange_block node do |_|
      add_dest_for_block node if node.id

      latex_content = extract_latex_content(node.content, node.style.to_sym)

      svg_output, error = stem_to_svg(latex_content, false)

      if svg_output.nil? || svg_output.empty?
        logger.warn "Failed to convert STEM to SVG: #{error} (Fallback to code block)"
        pad_box @theme.code_padding, node do
          theme_font :code do
            typeset_formatted_text [{ text: (guard_indentation latex_content), color: @font_color }],
                                   (calc_line_metrics @base_line_height),
                                   bottom_gutter: @bottom_gutters[-1][node]
          end
        end
      else
        svg_output = adjust_svg_color(svg_output, @font_color)
        svg_file = Tempfile.new(['stem', '.svg'])
        begin
          svg_file.write(svg_output)
          svg_file.close

          pad_box @theme.code_padding, node do
            begin
              image_obj = image svg_file.path, position: :center
              logger.debug "Successfully embedded stem block (as latex) #{latex_content} as SVG image" if image_obj
            rescue Prawn::Errors::UnsupportedImageType => e
              logger.warn "Unsupported image type error: #{e.message}"
            rescue StandardError => e
              logger.warn "Failed embedding SVG: #{e.message}"
            end
          end
        ensure
          svg_file.unlink
        end
      end
    end
    theme_margin :block, :bottom, (next_enclosed_block node)
  end

  def convert_inline_quoted node
    latex_content = extract_latex_content(node.text, node.type)
    return super if latex_content.nil?

    theme = (load_theme node.document)

    svg_output, error = stem_to_svg(latex_content, true)
    adjusted_svg, svg_width = adjust_svg_to_match_text(svg_output, node, theme)
    if adjusted_svg.nil? || adjusted_svg.empty?
      logger.warn "Error processing stem: #{error || 'No SVG output'}"
      return super
    end

    tmp_svg = Tempfile.new(['stem-', '.svg'])
    self.class.tempfiles << tmp_svg
    begin
      tmp_svg.write(adjusted_svg)
      tmp_svg.close

      logger.debug "Successfully embedded stem inline #{node.text} as SVG image"
      quoted_text = "<img src=\"#{tmp_svg.path}\" format=\"svg\" width=\"#{svg_width}\" alt=\"#{node.text}\">"
      node.id ? %(<a id="#{node.id}">#{DummyText}</a>#{quoted_text}) : quoted_text
    rescue => e
      logger.warn "Failed to process SVG: #{e.message}"
      super
    end
  end

  private

  def extract_latex_content(content, type)
    content = content.strip.gsub("&amp;", "&").gsub("&lt;", "<").gsub("&gt;", ">")
    case type
    when :latexmath
      return content
    when :asciimath
      return AsciiMath.parse(content).to_latex
    else
      return nil
    end
  end

  def adjust_svg_color(svg_output, font_color)
    svg_output.gsub(MATHJAX_DEFAULT_COLOR_STRING, "##{font_color}")
  end

  def stem_to_svg(latex_content, is_inline)
    js_script = File.join(File.dirname(__FILE__), '../bin/render.js')
    svg_output, error = nil, nil
    format = is_inline ? 'inline-TeX' : 'TeX'
    Open3.popen3('node', js_script, latex_content, format, POINTS_PER_EX.to_s) do |_, stdout, stderr, wait_thr|
      svg_output = stdout.read
      error = stderr.read unless wait_thr.value.success?
    end
    [svg_output, error]
  end

  def adjust_svg_to_match_text(svg_content, node, theme)
    node_context = find_font_context(node)
    logger.debug "Found font context #{node_context} for node #{node}"

    if node_context.is_a?(Asciidoctor::Section)
      level = node_context.level.next
      theme_key = "heading_h#{level}"
      if node_context.sectname == 'abstract'
        theme_key = 'abstract_title'
      end

      font_family = theme["#{theme_key}_font_family"] || theme['heading_font_family'] || theme['base_font_family'] || FALLBACK_FONT_FAMILY
      font_style = theme["#{theme_key}_font_style"] || theme['heading_font_style'] || theme['base_font_style'] || FALLBACK_FONT_STYLE
      font_size = theme["#{theme_key}_font_size"] || theme['heading_font_size'] || theme['base_font_size'] || FALLBACK_FONT_SIZE
      font_color = theme["#{theme_key}_font_color"] || theme['heading_font_color'] || theme['base_font_color'] || FALLBACK_FONT_COLOR
    else
      if node_context.parent.is_a?(Asciidoctor::Section) && node_context.parent.sectname == 'abstract'
        theme_key = :abstract
      else
        theme_key = :base
      end

      font_family = nil
      font_style = nil
      font_size = nil
      font_color = nil
      converter = node_context.converter
      converter.theme_font theme_key do
        font_family = converter.font_family || FALLBACK_FONT_FAMILY
        font_style = converter.font_style || FALLBACK_FONT_STYLE
        font_size = converter.font_size || FALLBACK_FONT_SIZE
        font_color = converter.font_color || FALLBACK_FONT_COLOR
      end
    end

    font_catalog = theme.font_catalog
    font_file = font_catalog[font_family][font_style.to_s]

    font = TTFunk::File.open(font_file)
    descender_height = font.horizontal_header.descent.abs
    ascender_height = font.horizontal_header.ascent.abs

    units_per_em = font.header.units_per_em.to_f
    total_height = (descender_height.to_f + ascender_height.to_f)

    embedding_text_height = total_height / units_per_em * font_size
    embedding_text_baseline_height = descender_height / units_per_em * font_size

    svg_doc = REXML::Document.new(svg_content)
    svg_width = svg_doc.root.attributes['width'].to_f * POINTS_PER_EX || raise("No width found in SVG")
    svg_height = svg_doc.root.attributes['height'].to_f * POINTS_PER_EX || raise("No height found in SVG")
    view_box = svg_doc.root.attributes['viewBox']&.split(/\s+/)&.map(&:to_f) || raise("No viewBox found in SVG")
    svg_inner_offset = view_box[1]
    svg_inner_height = view_box[3]

    svg_default_font_size = FALLBACK_FONT_SIZE

    # Adjust SVG height and width so that math font matches embedding text
    scaling_factor = font_size.to_f / svg_default_font_size
    svg_width = svg_width * scaling_factor
    svg_height = svg_height * scaling_factor

    svg_height_difference = embedding_text_height - svg_height
    svg_relative_height_difference = embedding_text_height / svg_height
    embedding_text_relative_baseline_height = embedding_text_baseline_height / embedding_text_height

    logger.debug "Original SVG height: #{svg_height.round(2)}, width: #{svg_width.round(2)}, inner height: #{svg_inner_height.round(2)}, inner offset: #{svg_inner_offset.round(2)}"
    if svg_height_difference < 0
      svg_relative_portion_extending_embedding_text_below = (1 - svg_relative_height_difference) / 2
      svg_relative_baseline_height = embedding_text_relative_baseline_height * svg_relative_height_difference
      svg_inner_relative_offset = svg_relative_baseline_height + svg_relative_portion_extending_embedding_text_below - 1

      svg_inner_offset = svg_inner_relative_offset * svg_inner_height
    else
      svg_height = embedding_text_height
      svg_inner_height = svg_relative_height_difference * svg_inner_height
      svg_inner_offset = (embedding_text_relative_baseline_height - 1) * svg_inner_height
    end

    view_box[1] = svg_inner_offset
    view_box[3] = svg_inner_height
    svg_doc.root.attributes['viewBox'] = view_box.join(' ')
    svg_doc.root.attributes['height'] = "#{svg_height / POINTS_PER_EX}ex"
    svg_doc.root.attributes['width'] = "#{svg_width / POINTS_PER_EX}ex"
    svg_doc.root.attributes.delete('style')

    logger.debug "Adjusted SVG height: #{svg_height.round(2)}, width: #{svg_width.round(2)}, inner height: #{svg_inner_height.round(2)}, inner offset: #{svg_inner_offset.round(2)}"
    svg_output = adjust_svg_color(svg_doc.to_s, font_color)

    [svg_output, svg_width]
  rescue => e
    logger.warn "Failed to adjust SVG baseline: #{e.full_message}"
    nil # Fallback to original if adjustment fails
  end

  def find_font_context(node)
    while node
      return node unless node.is_a?(Asciidoctor::Inline)
      node = node.parent
    end
    node
  end
end
