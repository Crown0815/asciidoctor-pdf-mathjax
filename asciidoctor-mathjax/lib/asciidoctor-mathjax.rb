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
#       tare_first_page_content_stream { theme_fill_and_stroke_block :code, extent, caption_node: node }

      # Get the LaTeX content from the STEM block
      latex_content = node.content.strip

      # Convert LaTeX to SVG using the render.js script
      svg_output, error = stem_to_svg(latex_content)

      if svg_output.nil? || svg_output.empty?
        warn "Failed to convert STEM to SVG: #{error}"
        # Fallback to rendering the raw LaTeX as text
        pad_box @theme.code_padding, node do
          theme_font :code do
            typeset_formatted_text [text: (guard_indentation latex_content), color: @font_color],
              (calc_line_metrics @base_line_height),
              bottom_gutter: @bottom_gutters[-1][node]
          end
        end
      else
        # Write SVG to a temporary file
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

              if image_obj
                puts "DEBUG: Image embedded successfully"
                # No need to manipulate extent.height; let Prawn handle layout
              else
                warn "Failed to embed SVG: Image object is nil"
              end
            rescue Prawn::Errors::UnsupportedImageType => e
              warn "Unsupported image type error: #{e.message}"
            rescue StandardError => e
              warn "Error embedding SVG: #{e.message}"
            end
          end
        ensure
          svg_file.unlink # Clean up the temp file
        end
      end
    end
    theme_margin :block, :bottom, (next_enclosed_block node)
  end


  private

  def stem_to_svg(latex_content)
    puts "DEBUG: Converting LaTeX to SVG: #{latex_content}"
    svg_output, error = nil
    js_script = File.join(File.dirname(__FILE__), '../bin/render.js')
    font_size = @theme.code_font_size
    Open3.popen3('node', js_script, latex_content) do |stdin, stdout, stderr, wait_thr|
      svg_output = stdout.read
      error = stderr.read
    end

    puts "DEBUG: SVG output: #{svg_output[0..80]}..."
    [svg_output, error]
  end
end
