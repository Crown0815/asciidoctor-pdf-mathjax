require 'asciidoctor-pdf' unless Asciidoctor::Converter.for 'pdf'
require 'open3'
require 'tempfile'

class AsciidoctorPDFExtensions < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def convert_stem node
    puts "DEBUG: arrange_block"
    arrange_block node do |extent|
      puts "DEBUG: add_dest_for_block"
      add_dest_for_block node if node.id
      puts "DEBUG: tare_first_page_content_stream"

      latex_content = node.content.strip
      svg_output, error = stem_to_svg(latex_content)

      if svg_output.nil? || svg_output.empty?
        warn "Failed to convert STEM to SVG: #{error}"
        pad_box @theme.code_padding, node do
          theme_font :code do
            typeset_formatted_text [{ text: (guard_indentation latex_content), color: @font_color }],
                                   (calc_line_metrics @base_line_height),
                                   bottom_gutter: @bottom_gutters[-1][node]
          end
        end
      else
        puts "DEBUG: Writing SVG to temporary file"
        svg_file = Tempfile.new(['stem', '.svg'])
        begin
          svg_file.write(svg_output)
          svg_file.close

          puts "DEBUG: SVG file path: #{svg_file.path}"
          puts "DEBUG: SVG file size: #{File.size(svg_file.path)} bytes"

          pad_box @theme.code_padding, node do
            begin
              image_obj = image svg_file.path, position: :center
              puts "DEBUG: Image object type: #{image_obj.class}"
              puts "DEBUG: Image object content: #{image_obj.inspect}"
              puts "DEBUG: Image embedded successfully" if image_obj
            rescue Prawn::Errors::UnsupportedImageType => e
              warn "Unsupported image type error: #{e.message}"
            rescue StandardError => e
              warn "Error embedding SVG: #{e.message}"
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

    tmp_svg = Tempfile.new(['stem-', '.svg'])
    begin
      tmp_svg.write(svg_output)
      tmp_svg.close
      @tmp_files ||= {}
      @tmp_files[tmp_svg.path] = tmp_svg.path

      # Explicitly specify format="svg" in the <img> tag
      "<img src=\"#{tmp_svg.path}\" format=\"svg\" width=\"50\" alt=\"[#{node.text}]\">"
    rescue => e
      puts "DEBUG: Failed to process SVG: #{e.message}"
      "<span>#{node.text}</span>"
    end
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
