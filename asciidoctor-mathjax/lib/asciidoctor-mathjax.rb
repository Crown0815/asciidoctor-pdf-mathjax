require 'asciidoctor'
require 'asciidoctor/extensions'
require 'open3'
require 'fileutils'

class MathJaxTreeprocessor < Asciidoctor::Extensions::Treeprocessor
  def initialize(*args)
    super
    @temp_dir = File.join(Dir.tmpdir, 'asciidoctor-pdf-mathjax')
    FileUtils.mkdir_p(@temp_dir)
  end

  def process(document)

    puts "DEBUG: Hello from MathJaxTreeprocessor"
    # Find all math nodes (block and inline STEM)
    math_nodes = document.find_by(context: :stem) { |node| node.style == :latexmath }
    return unless math_nodes

    math_nodes.each_with_index do |node, index|
      # Determine desired font size based on context
      desired_font_size = get_desired_font_size(node, document)

      # Generate SVG with fixed font size (12pt)
      fixed_font_size = 12
      svg_file = File.join(@temp_dir, "mathjax_svg_#{index}.svg")
      generate_svg(node.content, fixed_font_size, svg_file)

      # Read SVG dimensions
      svg_width, svg_height = extract_svg_dimensions(svg_file)
      next unless svg_width && svg_height

      # Calculate scaling factor
      scaling_factor = desired_font_size.to_f / fixed_font_size
      scaled_width = svg_width * scaling_factor
      scaled_height = svg_height * scaling_factor

      # Create image node
      image_node = create_image_node(node, document, svg_file, scaled_width, scaled_height)
      node.parent.replace(node, image_node)
    end

    document
  end

  private

  # Determine font size based on node context
  def get_desired_font_size(node, document)
    base_font_size = (document.attributes['base-font-size'] || 10).to_f
    if node.context == :stem && node.parent.context == :paragraph # Inline
      document.attributes['math-inline-font-size']&.to_f || base_font_size
    else # Block
      document.attributes['math-block-font-size']&.to_f || base_font_size * 1.2 # Slightly larger for blocks
    end
  end

  # Generate SVG using MathJax via Node.js script
  def generate_svg(expression, font_size, output_file)
    js_script = File.join(File.dirname(__FILE__), '../mathjax/render.js')
    cmd = "node #{js_script} #{font_size} \"#{escape_expression(expression)}\" #{output_file}"
    stdout, stderr, status = Open3.capture3(cmd)
    unless status.success?
      warn "MathJax rendering failed: #{stderr}"
      return nil
    end
    output_file
  end

  # Extract width and height from SVG
  def extract_svg_dimensions(svg_file)
    svg_content = File.read(svg_file)
    if svg_content =~ /width="([\d.]+)(?:ex|px)"\s+height="([\d.]+)(?:ex|px)"/
      width, height = $1.to_f, $2.to_f
      # Convert ex to pt (approx 1 ex = 0.5em, 1em ≈ 12pt base, adjust as needed)
      [width * 6, height * 6] # Rough conversion assuming 1ex ≈ 6pt
    else
      warn "Could not extract dimensions from SVG: #{svg_file}"
      nil
    end
  end

  # Create an image node for PDF inclusion
  def create_image_node(node, document, svg_file, width, height)
    image_node = Asciidoctor::Block.new(document, :image, source: "image::#{svg_file}[]")
    image_node.attributes['target'] = svg_file
    image_node.attributes['width'] = width.round(2).to_s # In points
    image_node.attributes['height'] = height.round(2).to_s # In points
    image_node.attributes['alt'] = 'Math expression'
    image_node
  end

  # Escape expression for shell execution
  def escape_expression(expr)
    expr.gsub('"', '\\"')
  end
end

# Register the extension
Asciidoctor::Extensions.register do
  tree_processor MathJaxTreeprocessor
end
