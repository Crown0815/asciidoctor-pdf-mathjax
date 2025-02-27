require 'asciidoctor_mathjax/renderer'

class MathJaxTreeProcessor < Asciidoctor::Extensions::TreeProcessor
  def process(document)
    puts "DEBUG: Starting MathJaxTreeProcessor for document: #{document.attributes['docfile']}"
    puts "DEBUG: Stem attribute: #{document.attributes['stem']}"
    if document.attributes['stem'] == 'latexmath'
      puts "DEBUG: Processing standard stem content with stem=latexmath"
      process_stem_blocks(document)
      process_stem_inlines(document)
    else
      puts "DEBUG: Skipping processing, stem is not 'latexmath'"
    end
    document # Return the document to continue processing chain
  end

  private

  def process_stem_blocks(document)
    puts "DEBUG: Searching for standard stem blocks"
    # Try :literal and :stem contexts with style 'stem'
    blocks = document.find_by(context: [:literal, :stem]) { |b| b.style == 'stem' }
    if blocks.empty?
      puts "DEBUG: No stem blocks found"
      # Log all blocks to see what's parsed
      all_blocks = document.find_by { |n| n.block? }
      puts "DEBUG: All blocks found: #{all_blocks.map { |b| { context: b.context, style: b.style, content: b.content } }.inspect}"
    else
      puts "DEBUG: Found #{blocks.size} stem blocks"
      blocks.each do |node|
        puts "DEBUG: Processing stem block with attrs: #{node.attributes.inspect}"
        math_expression = node.content
        puts "DEBUG: Block content: #{math_expression}"
        image_path = MathJaxRenderer.new(document).generate_math_image(math_expression, true)
        puts "DEBUG: Generated block image at: #{image_path}"
        node.replace_with(create_image_block(node.parent, image_path))
      end
    end
  end

  def process_stem_inlines(document)
    puts "DEBUG: Searching for stem inlines"
    # Find inline macros with target 'stem'
    inlines = document.find_by(context: :inline) { |n| n.type == :inline_macro && n.target == 'stem' }
    if inlines.empty?
      puts "DEBUG: No stem inlines found"
      # Log all inline nodes to see what's parsed
      all_inlines = document.find_by(context: :inline)
      puts "DEBUG: All inline nodes found: #{all_inlines.map { |n| { type: n.type, target: n.respond_to?(:target) ? n.target : 'N/A', text: n.text } }.inspect}"
    else
      puts "DEBUG: Found #{inlines.size} stem inlines"
      inlines.each do |node|
        puts "DEBUG: Processing stem inline with attrs: #{node.attributes.inspect}, target: #{node.target}"
        math_expression = node.text
        puts "DEBUG: Inline content: #{math_expression}"
        image_path = MathJaxRenderer.new(document).generate_math_image(math_expression, false)
        puts "DEBUG: Generated inline image at: #{image_path}"
        node.replace_with(create_image_inline(node.parent, image_path))
      end
    end
  end

  def create_image_block(parent, image_path)
    Asciidoctor::Block.new(parent, :image, :content_model => :empty, :attributes => { 'target' => image_path, 'alt' => 'Math Expression' })
  end

  def create_image_inline(parent, image_path)
    Asciidoctor::Inline.new(parent, :image, nil, :attributes => { 'target' => image_path, 'alt' => 'Inline Math' })
  end
end
