require 'asciidoctor-pdf' unless Asciidoctor::Converter.for 'pdf'
require 'open3'
require 'tempfile'
require 'rexml/document'
require 'ttfunk'

class AsciidoctorPDFExtensions < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def convert_stem node
    arrange_block node do |extent|
      add_dest_for_block node if node.id

      latex_content = node.content.strip
      svg_output, error = stem_to_svg(latex_content)

      if svg_output.nil? || svg_output.empty?
        warn "Failed to convert STEM to SVG: #{error} (Fallback to code block)"
        pad_box @theme.code_padding, node do
          theme_font :code do
            typeset_formatted_text [{ text: (guard_indentation latex_content), color: @font_color }],
                                   (calc_line_metrics @base_line_height),
                                   bottom_gutter: @bottom_gutters[-1][node]
          end
        end
      else
        puts "DEBUG: Successfully converted STEM to SVG"
        svg_file = Tempfile.new(['stem', '.svg'])
        begin
          svg_file.write(svg_output)
          svg_file.close

          pad_box @theme.code_padding, node do
            begin
              image_obj = image svg_file.path, position: :center
              puts "DEBUG: Successfully embedded SVG image" if image_obj
            rescue Prawn::Errors::UnsupportedImageType => e
              warn "Unsupported image type error: #{e.message}"
            rescue StandardError => e
              warn "Failed embedding SVG: #{e.message}"
            end
          end
        ensure
          svg_file.unlink
        end
      end
    end
    theme_margin :block, :bottom, (next_enclosed_block node)
  end

  EX_TO_PT = 6

  def convert_inline_quoted node

    puts "DEBUG: convert inline_quoted node '#{node.text[0..20]}' of type #{node.type}"
    if node.type != :asciimath && node.type != :latexmath
      return super
    end
    puts "DEBUG: Processing math node '#{node.text}'"

    svg_output, error = stem_to_svg(node.text)
    if svg_output.nil? || svg_output.empty?
      puts "DEBUG: Error processing stem: #{error || 'No SVG output'}"
      return "<span>#{node.text}</span>"
    end

    # Adjust SVG to align baseline with bottom
    adjusted_svg, svg_width = adjust_svg_baseline(svg_output, node)
    tmp_svg = Tempfile.new(['stem-', '.svg'])
    begin
      puts "DEBUG: Writing inline_quoted math node '#{node.text}' to SVG: #{tmp_svg.path}"
      tmp_svg.write(adjusted_svg)
      tmp_svg.close
      @tmp_files ||= {}
      @tmp_files[tmp_svg.path] = tmp_svg.path

      puts "DEBUG: <img src=\"#{tmp_svg.path}\" format=\"svg\" width=\"#{svg_width}\" alt=\"[#{node.text}]\">"
      "<img src=\"#{tmp_svg.path}\" format=\"svg\" width=\"#{svg_width}\" alt=\"[#{node.text}]\">"
    rescue => e
      puts "DEBUG: Failed to process SVG: #{e.message}"
      "<span>#{node.text}</span>"
    end
  end

  private

  def stem_to_svg(latex_content)
    js_script = File.join(File.dirname(__FILE__), '../bin/render.js')
    svg_output, error = nil, nil
    Open3.popen3('node', js_script, latex_content) do |_, stdout, stderr, wait_thr|
      svg_output = stdout.read
      error = stderr.read unless wait_thr.value.success?
    end
    [svg_output, error]
  end

  def adjust_svg_baseline(svg_content, node)
    doc = node.document

    converter = doc.instance_variable_get(:@converter)
    theme = converter.instance_variable_get(:@theme)
    theme_table = theme.instance_variable_get(:@table)

    # Access the attributes
    font_family = theme_table[:base_font_family]
    font_style = theme_table[:base_font_style]
    font_size = theme_table[:base_font_size]

    # Access the font_catalog entry
    font_catalog = theme_table[:font_catalog]
    font_file = font_catalog[font_family][font_style.to_s]

    font = TTFunk::File.open(font_file)
    descender_height = font.horizontal_header.descent.abs
    ascender_height = font.horizontal_header.ascent.abs

    units_per_em = font.header.units_per_em.to_f
    total_height = (descender_height.to_f + ascender_height.to_f)

    embedding_text_height = total_height / units_per_em * font_size
    embedding_text_baseline_height = descender_height / units_per_em * font_size

    puts "Embedding in font #{font_family}-#{font_style} size #{font_size}pt (text height: #{embedding_text_height.round(2)}pt, baseline #{embedding_text_baseline_height.round(2)}pt)"



    svg_doc = REXML::Document.new(svg_content)
    svg_width = svg_doc.root.attributes['width'].to_f * EX_TO_PT || raise("No width found in SVG")
    svg_height = svg_doc.root.attributes['height'].to_f * EX_TO_PT || raise("No height found in SVG")
    view_box = svg_doc.root.attributes['viewBox']&.split(/\s+/)&.map(&:to_f) || raise("No viewBox found in SVG")
    svg_inner_offset = view_box[1]
    svg_inner_height = view_box[3]

    svg_height_difference = embedding_text_height - svg_height
    if svg_height_difference < 0
      puts "DEBUG: SVG height is greater than embedding text height: #{svg_height} > #{embedding_text_height}"
    else
      puts "DEBUG: SVG height is less than embedding text height: #{svg_height} < #{embedding_text_height}"
      puts "DEBUG: Original SVG height: #{svg_height}, inner height: #{svg_inner_height}, inner offset: #{svg_inner_offset}"
      svg_relative_height_difference = embedding_text_height / svg_height

      embedding_text_relative_baseline_height = embedding_text_baseline_height / embedding_text_height

      svg_inner_height = svg_relative_height_difference * svg_inner_height
      svg_inner_offset = (embedding_text_relative_baseline_height - 1) * svg_inner_height
      svg_height = embedding_text_height

      view_box[1] = svg_inner_offset
      view_box[3] = svg_inner_height
      svg_doc.root.attributes['viewBox'] = view_box.join(' ')
      svg_doc.root.attributes['height'] = "#{svg_height / EX_TO_PT}ex"
      svg_doc.root.attributes.delete('style')

      puts "DEBUG: Adjusted SVG height: #{svg_height}, inner height: #{svg_inner_height}, inner offset: #{svg_inner_offset}"
    end


    [svg_doc.to_s, svg_width]
  rescue => e
    puts "DEBUG: Failed to adjust SVG baseline: #{e.message}"
    svg_content # Fallback to original if adjustment fails
  end
end
