require 'asciidoctor-pdf' unless Asciidoctor::Converter.for 'pdf'
require 'open3'
require 'tempfile'
require 'rexml/document'

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
    adjusted_svg = adjust_svg_baseline(svg_output)
    tmp_svg = Tempfile.new(['stem-', '.svg'])
    begin
      puts "DEBUG: Writing inline_quoted math node '#{node.text}' to SVG: #{tmp_svg.path}"
      puts "DEBUG: Adjusted SVG content: #{adjusted_svg}..."
      tmp_svg.write(adjusted_svg)
      tmp_svg.close
      @tmp_files ||= {}
      @tmp_files[tmp_svg.path] = tmp_svg.path

      # Scale to font size using width only
      target_height = font_size || @root_font_size || 12
      svg_doc = REXML::Document.new(svg_output) # Use original for dimensions
      view_box = svg_doc.root.attributes['viewBox']&.split(/\s+/)&.map(&:to_f) || [0, 0, 50, 20]
      intrinsic_width = view_box[2]
      intrinsic_height = view_box[3]
      aspect_ratio = intrinsic_width / intrinsic_height
      scaled_width = target_height * aspect_ratio

      puts "DEBUG: Font size: #{font_size || 'nil'}, Root font size: #{@root_font_size}, Target height: #{target_height}, Aspect ratio: #{aspect_ratio}, Scaled width: #{scaled_width}"

      # Use width and format attributes only
      "<img src=\"#{tmp_svg.path}\" format=\"svg\" width=\"#{scaled_width}\" alt=\"[#{node.text}]\">"
    rescue => e
      puts "DEBUG: Failed to process SVG: #{e.message}"
      "<span>#{node.text}</span>"
    end
  end

  private

  def stem_to_svg(latex_content)
    puts "DEBUG: Converting LaTeX to SVG: #{latex_content}"
    js_script = File.join(File.dirname(__FILE__), '../bin/render.js')
    svg_output, error = nil, nil
    Open3.popen3('node', js_script, latex_content) do |_, stdout, stderr, wait_thr|
      svg_output = stdout.read
      error = stderr.read unless wait_thr.value.success?
    end
    puts "DEBUG: SVG output: #{svg_output[0..80]}..."
    [svg_output, error]
  end

  def adjust_svg_baseline(svg_content)
    svg_doc = REXML::Document.new(svg_content)
    view_box = svg_doc.root.attributes['viewBox']&.split(/\s+/)&.map(&:to_f) || [0, 0, 50, 20]
    min_y = view_box[1] # Bottom of SVG (negative)
    intrinsic_height = view_box[3]

    # Calculate shift to move y=0 to bottom
    shift_y = -min_y # Positive value to shift content up

    # Adjust the transform on the root <g> element
    g_elem = svg_doc.root.elements['g']
    if g_elem
      current_transform = g_elem.attributes['transform'] || ''
      new_transform = "#{current_transform} translate(0, #{shift_y})".strip
      g_elem.attributes['transform'] = new_transform
    end

    # Update viewBox to reflect new bounds
    view_box[1] = 0 # New min_y after shift
    view_box[3] = intrinsic_height + min_y # New height
    svg_doc.root.attributes['viewBox'] = view_box.join(' ')

    # Remove vertical-align style
    svg_doc.root.attributes.delete('style')

    svg_doc.to_s
  rescue => e
    puts "DEBUG: Failed to adjust SVG baseline: #{e.message}"
    svg_content # Fallback to original if adjustment fails
  end
end
