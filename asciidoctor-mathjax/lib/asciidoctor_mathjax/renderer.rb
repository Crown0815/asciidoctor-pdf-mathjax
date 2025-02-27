require 'fileutils'
require 'securerandom'
require 'open3'

class MathJaxRenderer
  def initialize(document)
    @document = document
    @cache = {}
    @images_dir = "#{document.attributes['imagesdir']}/tmp" # Write to /code/testing/
    FileUtils.mkdir_p(@images_dir) unless Dir.exist?(@images_dir)
  end

  def generate_math_image(math_expression, is_block, image_path = nil)
    cache_key = [math_expression, is_block]
    return @cache[cache_key] if @cache.key?(cache_key)

    image_path ||= File.join(@images_dir, "math_#{SecureRandom.hex(4)}.svg")
    render_to_svg(math_expression, is_block, image_path)
    @cache[cache_key] = File.basename(image_path) # Store relative path
    File.basename(image_path)
  end

  private

  def render_to_svg(math_expression, is_block, image_path)
    script_path = Gem.bin_path('asciidoctor-mathjax', 'mathjax-render.js')
    escaped_expression = math_expression.gsub('"', '\"')
    command = "node #{script_path} \"#{escaped_expression}\" \"#{image_path}\" #{is_block}"

    puts "DEBUG: Running command: #{command}"
    stdout, stderr, status = Open3.capture3(command)
    puts "DEBUG: Command output: #{stdout}"
    puts "DEBUG: Command error: #{stderr}" if !stderr.empty?
    if status.success?
      puts "DEBUG: Generated SVG at #{image_path}"
      return image_path
    else
      warn "Failed to render math: #{stderr}"
      'error.svg'
    end
  end
end
