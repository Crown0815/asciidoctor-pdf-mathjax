require 'asciidoctor'
require 'asciidoctor/extensions'
require 'open3'
require 'fileutils'

class MathJaxTreeProcessor < Asciidoctor::Extensions::TreeProcessor
  def initialize(*args)
    super
    @temp_dir = File.join(Dir.tmpdir, 'asciidoctor-pdf-mathjax')
    FileUtils.mkdir_p(@temp_dir)
    puts "DEBUG: MathJaxTreeProcessor initialized with temp_dir: #{@temp_dir}"
  end

  def process(document)
    puts "DEBUG: Processing document with #{document.attributes.keys.length} attributes"
    math_nodes = document.find_by(context: :stem)
    unless math_nodes
      puts "DEBUG: No STEM nodes found in document"
      return
    end

    puts "DEBUG: Found #{math_nodes.length} STEM nodes"
    math_nodes.each do |node|
      puts "DEBUG: Node style: #{node.style || 'none'}"
    end

    math_nodes.each_with_index do |node, index|
      puts "DEBUG: Processing node ##{index}: #{node.content[0..20]}..."
      desired_font_size = get_desired_font_size(node, document)
      puts "DEBUG: Desired font size for node ##{index}: #{desired_font_size}pt"

      fixed_font_size = 12
      svg_file = File.join(@temp_dir, "mathjax_svg_#{index}.svg")
      generate_svg(node.content, fixed_font_size, svg_file)

      svg_width, svg_height = extract_svg_dimensions(svg_file)
      if svg_width && svg_height
        puts "DEBUG: SVG dimensions for node ##{index}: #{svg_width}x#{svg_height}"
        scaling_factor = desired_font_size.to_f / fixed_font_size
        scaled_width = svg_width * scaling_factor
        scaled_height = svg_height * scaling_factor
        puts "DEBUG: Scaled dimensions for node ##{index}: #{scaled_width.round(2)}x#{scaled_height.round(2)}"

        image_node = create_image_node(node, document, svg_file, scaled_width, scaled_height)
        node.parent.replace(node, image_node)
        puts "DEBUG: Replaced node ##{index} with image node targeting #{svg_file}"
      else
        puts "DEBUG: Skipping node ##{index} due to missing SVG dimensions"
      end
    end

    document
  end

  private

  def get_desired_font_size(node, document)
    base_font_size = (document.attributes['base-font-size'] || 10).to_f
    if node.context == :stem && node.parent.context == :paragraph
      document.attributes['math-inline-font-size']&.to_f || base_font_size
    else
      document.attributes['math-block-font-size']&.to_f || base_font_size * 1.2
    end
  end

  def generate_svg(expression, font_size, output_file)
    js_script = File.join(File.dirname(__FILE__), '../bin/render.js')
    cmd = "node #{js_script} #{font_size} \"#{escape_expression(expression)}\" #{output_file}"
    puts "DEBUG: Executing MathJax command: #{cmd}"
    stdout, stderr, status = Open3.capture3(cmd)
    unless status.success?
      puts "DEBUG: MathJax rendering failed for '#{expression[0..20]}...': #{stderr}"
      return nil
    end
    puts "DEBUG: Generated SVG at #{output_file}"
    output_file
  end

  def extract_svg_dimensions(svg_file)
    svg_content = File.read(svg_file)
    if svg_content =~ /width="([\d.]+)(?:ex|px)"\s+height="([\d.]+)(?:ex|px)"/
      width, height = $1.to_f, $2.to_f
      [width * 6, height * 6]
    else
      puts "DEBUG: Could not extract dimensions from SVG: #{svg_file}"
      nil
    end
  end

  def create_image_node(node, document, svg_file, width, height)
    image_node = Asciidoctor::Block.new(document, :image, source: "image::#{svg_file}[]")
    image_node.attributes['target'] = svg_file
    image_node.attributes['width'] = width.round(2).to_s
    image_node.attributes['height'] = height.round(2).to_s
    image_node.attributes['alt'] = 'Math expression'
    image_node
  end

  def escape_expression(expr)
    expr.gsub('"', '\\"')
  end
end

# Register the extension with debug message
Asciidoctor::Extensions.register do
  puts "DEBUG: Registering MathJaxTreeProcessor extension"
  tree_processor MathJaxTreeProcessor
end
