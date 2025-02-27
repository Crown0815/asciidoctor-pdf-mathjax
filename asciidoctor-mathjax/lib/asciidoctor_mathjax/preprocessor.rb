require 'asciidoctor_mathjax/renderer'
require 'fileutils'

class MathJaxPreprocessor < Asciidoctor::Extensions::Preprocessor
  def process(document, reader)
    puts "DEBUG: Starting MathJaxPreprocessor for document: #{document.attributes['docfile']}"
    puts "DEBUG: Stem attribute: #{document.attributes['stem']}"
    return reader unless document.attributes['stem'] == 'latexmath'

    lines = reader.read_lines
    in_stem_block = false
    block_content = []
    new_lines = []

    dirname = File.dirname("#{document.attributes['imagesdir']}/tmp")
    unless File.directory?(dirname)
      FileUtils.mkdir_p(dirname)
    end
    FileUtils.rm_rf("#{document.attributes['imagesdir']}/tmp/*")

    lines.each_with_index do |line, index|
      if line =~ /^\[stem\]$/ && lines[index + 1] =~ /^\+\+\+\+$/
        puts "DEBUG: Found stem block start at line #{index + 1}"
        in_stem_block = true
        block_content = []
        new_lines << line # Keep [stem]
      elsif in_stem_block && line =~ /^\+\+\+\+$/
        if block_content.empty? # Opening delimiter
          next
        else
          puts "DEBUG: Found stem block end at line #{index + 1}"
          in_stem_block = false
          math_expression = block_content.join("\n").strip
          puts "DEBUG: Block content: #{math_expression}"
          image_path = "#{document.attributes['imagesdir']}/tmp/math_#{SecureRandom.hex(4)}.svg"
          MathJaxRenderer.new(document).generate_math_image(math_expression, true, image_path)
          puts "DEBUG: Generated block image at: #{image_path} (#{File.exist?(image_path) ? 'success' : 'failed'})"
          new_lines << "image::#{image_path}[Math Expression]"
        end
      elsif in_stem_block
        block_content << line
      elsif line =~ /stem:\[(.*?)\]/
        puts "DEBUG: Found stem inline at line #{index + 1}: #{$1}"
        math_expression = $1
        image_path = "#{document.attributes['imagesdir']}/tmp/math_#{SecureRandom.hex(4)}.svg"
        MathJaxRenderer.new(document).generate_math_image(math_expression, false, image_path)
        puts "DEBUG: Generated inline image at: #{image_path} (#{File.exist?(image_path) ? 'success' : 'failed'})"
        new_lines << line.sub(/stem:\[.*?\]/, "image:#{image_path}[Inline Math]")
      else
        new_lines << line
      end
    end

    reader.push_include(new_lines, document.attributes['docfile'], 'input.adoc', 1, {})
    reader
  end
end
