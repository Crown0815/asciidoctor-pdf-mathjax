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

  def convert_inline_quoted node
    doc = node.document

    # Assuming 'doc' is the Asciidoctor::Document object
    converter = doc.instance_variable_get(:@converter)
    theme = converter.instance_variable_get(:@theme)
    theme_table = theme.instance_variable_get(:@table)

    # Access the attributes
    base_font_family = theme_table[:base_font_family]
    base_font_style = theme_table[:base_font_style]
    base_font_size = theme_table[:base_font_size]
    base_line_height_length = theme_table[:base_line_height_length]
    base_line_height = theme_table[:base_line_height]

    # Access the font_catalog entry
    font_catalog = theme_table[:font_catalog]
    font_file = font_catalog[base_font_family][base_font_style.to_s]  # "/usr/lib/ruby/gems/3.3.0/gems/asciidoctor-pdf-2.3.19/data/fonts/notoserif-regular-subset.ttf"

    font = TTFunk::File.open(font_file)
    puts "DEBUG: hhea: #{font.pretty_inspect}"
    hhea = font.horizontal_header
    puts "DEBUG: hhea: #{hhea.pretty_inspect}"
    descender_height = hhea.descent.abs
    ascender_height = hhea.ascent.abs

    font_size = base_font_size
    upem = font.header.units_per_em
    total_height = (descender_height.to_f + ascender_height.to_f)
    descender_height_ratio = (descender_height.to_f / total_height)
    descender_height_in_points = descender_height_ratio * font_size

    # Output the scaled descender height

    # Optional: Print the results
    puts "Base Font Family: #{base_font_family}"
    puts "Base Font Style: #{base_font_style}"
    puts "Base Font Size: #{base_font_size}"
    puts "Base Line Height Length: #{base_line_height_length}"
    puts "Base Line Height: #{base_line_height}"
    puts "Font File: #{font_file}"
    puts "Ascender height in font units: #{ascender_height}, unit per em ratio #{ascender_height / upem.to_f}"
    puts "Descender height in font units: #{descender_height}, unit per em ratio #{descender_height / upem.to_f}"
    puts "Total height in font units: #{total_height.to_s}, unit per em: #{upem}, ratio #{total_height / upem.to_f}"
    puts "Descender height ratio: #{descender_height_ratio}"
    puts "Descender height ratio font size #{font_size}pt: #{descender_height_in_points.round(2)}pt"



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
    target_font_size = font_size || @root_font_size || 12
    adjusted_svg = adjust_svg_baseline(svg_output, target_font_size)
    tmp_svg = Tempfile.new(['stem-', '.svg'])
    begin
      puts "DEBUG: Writing inline_quoted math node '#{node.text}' to SVG: #{tmp_svg.path}"
      puts "DEBUG: Raw SVG content: #{svg_output[0..80]}..."
      puts "DEBUG: Adjusted SVG content: #{adjusted_svg[0..80]}..."
      tmp_svg.write(adjusted_svg)
      tmp_svg.close
      @tmp_files ||= {}
      @tmp_files[tmp_svg.path] = tmp_svg.path

      # Scale to font size using width only
      svg_doc = REXML::Document.new(svg_output) # Use original for dimensions
      svg_width = svg_doc.root.attributes['width'].to_f
      default_font_size = 12
      ex_per_px = 6 # Assume 6ex width
      scaled_width = target_font_size / default_font_size * svg_width * ex_per_px

      puts "DEBUG: Font size: #{font_size}, Root font size: #{@root_font_size}, Target font size: #{target_font_size || 'nil'}, SVG-width: #{svg_width}, Scaled width: #{scaled_width}"
      puts "DEBUG: <img src=\"#{tmp_svg.path}\" format=\"svg\" width=\"#{scaled_width}\" alt=\"[#{node.text}]\">"
      "<img src=\"#{tmp_svg.path}\" format=\"svg\" width=\"#{scaled_width}\" alt=\"[#{node.text}]\">"
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

  def adjust_svg_baseline(svg_content, font_size)
    svg_doc = REXML::Document.new(svg_content)
    view_box = svg_doc.root.attributes['viewBox']&.split(/\s+/)&.map(&:to_f) || raise("No viewBox found in SVG")
    width = svg_doc.root.attributes['width'].to_f || raise("No width found in SVG")
    height = svg_doc.root.attributes['height'].to_f || raise("No height found in SVG")
    vertical_align = svg_doc.root.attributes['style']&.match(/vertical-align:\s*([-.\d]+)ex/)&.captures&.first&.to_f || raise("No vertical alignment found in SVG")

    puts "DEBUG: Adjusting SVG baseline: viewBox=#{view_box}, width=#{width}, height=#{height}, font_size=#{font_size}, vertical_align=#{vertical_align}"

    svg_width = svg_doc.root.attributes['width'].to_f
    default_font_size = 12
    scaled_width = font_size / default_font_size * svg_width
    height_embedding_text = font_size / 6 # Assume 6ex height

    aspect_ratio = height / width
    puts "DEBUG: SVG aspect ratio: #{aspect_ratio}, scaled_width=#{scaled_width}, height_embedding_text=#{height_embedding_text}"

    outer_offset = (scaled_width * aspect_ratio - height_embedding_text) / 2 + vertical_align
    puts "DEBUG: Outer offset: #{outer_offset}"

    view_box_height = view_box[3]
    puts "DEBUG: viewBox height: #{view_box_height}"
    inner_offset = view_box_height * outer_offset / height
    puts "DEBUG: Inner offset: #{inner_offset}"

    view_box_min_y = view_box[1]
    puts "DEBUG: Inner offset: #{inner_offset}"
    view_box_min_y_new = view_box_min_y - inner_offset
    puts "DEBUG: New viewBox min-y: #{view_box_min_y_new}"

    view_box[1] = view_box_min_y_new
    puts "DEBUG: Adjusted SVG baseline: viewBox=#{view_box}, width=#{width}, height=#{height}, font_size=#{font_size}, vertical_align=#{vertical_align}"
    svg_doc.root.attributes['viewBox'] = view_box.join(' ')
    svg_doc.root.attributes['style'] = "border:1px solid black"
    # svg_doc.root.attributes.delete('style')

    svg_doc.to_s
  rescue => e
    puts "DEBUG: Failed to adjust SVG baseline: #{e.message}"
    svg_content # Fallback to original if adjustment fails
  end
end
