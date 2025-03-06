require 'asciidoctor'
require 'asciidoctor/extensions'
require 'open3'
require 'fileutils'
require 'nokogiri'

class MathJaxTreeProcessor < Asciidoctor::Extensions::TreeProcessor
  LineFeed = %(\n)
  StemInlineMacroRx = /\\?(stem|(?:latex|ascii)math):([a-z,]*)\[(.*?[^\\])\]/m

  def process document
    return unless document.attr? 'stem'

    puts "DEBUG: MathJaxTreeProcessor processing document: #{document.attributes['docfile']}"
    puts "DEBUG: Processing document with stem attribute: #{document.attributes['stem']}"

    # The no-args constructor defaults to SVG and standard delimiters ($..$ for inline, $$..$$ for block)
    image_output_dir, image_target_dir = image_output_and_target_dir document
    ::Asciidoctor::Helpers.mkdir_p image_output_dir unless ::File.directory? image_output_dir
    puts "DEBUG: Image output dir: #{image_output_dir}, target dir: #{image_target_dir}"

    (document.find_by context: :stem, traverse_documents: true).each do |stem|
      handle_stem_block stem, image_output_dir, image_target_dir
    end

    document.find_by(traverse_documents: true) {|b|
      (b.content_model == :simple && (b.subs.include? :macros)) || b.context == :list_item
    }.each do |prose|
      handle_prose_block prose, image_output_dir, image_target_dir
    end

    (document.find_by content: :section).each do |sect|
      handle_section_title sect, image_output_dir, image_target_dir
    end

    document.remove_attr 'stem'
    (document.instance_variable_get :@header_attributes).delete 'stem' rescue nil

    nil
  end

  private

  def image_output_and_target_dir(doc)
    output_dir = doc.attr('imagesoutdir')
    if output_dir
      if doc.attr('imagesdir').nil_or_empty?
        target_dir = output_dir
      else
        # When imagesdir attribute is set, every relative path is prefixed with it. So the real target dir shall then be relative to the imagesdir, instead of being relative to document root.
        abs_imagesdir = ::Pathname.new doc.normalize_system_path(doc.attr('imagesdir'))
        abs_outdir = ::Pathname.new doc.normalize_system_path(output_dir)
        target_dir = abs_outdir.relative_path_from(abs_imagesdir).to_s
      end
    else
      output_dir = doc.attr('imagesdir')
      # since we store images directly to imagesdir, target dir shall be NULL and asciidoctor converters will prefix imagesdir.
      target_dir = "."
    end

    output_dir = doc.normalize_system_path(output_dir, doc.attr('docdir'))
    return [output_dir, target_dir]
  end

  def handle_stem_block(stem, image_output_dir, image_target_dir)
    equation_type = stem.style.to_sym

    case equation_type
    when :latexmath
      content = stem.content
    when :asciimath
      content = AsciiMath.parse(stem.content).to_latex
    else
      return
    end

    puts "DEBUG: Processing stem block with content: #{content}"

    desired_font_size = get_desired_font_size(stem, false)
    puts "DEBUG: Desired font size: #{desired_font_size}"
    img_target, _ = generate_svg content, stem.id, false, desired_font_size, image_output_dir, image_target_dir
    puts "DEBUG: Generated SVG at #{img_target}"

    parent = stem.parent

    alt_text = stem.attr 'alt', (equation_type == :latexmath ? %($$#{content}$$) : %(`#{content}`))
    attrs = {'target' => img_target, 'alt' => alt_text, 'align' => 'center'}

    parent = stem.parent
    stem_image = create_image_block parent, attrs
    stem_image.id = stem.id if stem.id
    if (title = stem.attributes['title'])
      stem_image.title = title
    end
    parent.blocks[parent.blocks.index stem] = stem_image
  end

  def handle_prose_block(prose, image_output_dir, image_target_dir)

    if prose.context == :list_item || prose.context == :table_cell
      use_text_property = true
      text = prose.instance_variable_get :@text
    else
      text = prose.lines * LineFeed
    end
    text, source_modified = handle_inline_stem prose, text, image_output_dir, image_target_dir
    if source_modified
      if use_text_property
        prose.text = text
      else
        prose.lines = text.split LineFeed
      end
    end
  end

  def handle_section_title(sect, image_output_dir, image_target_dir)
    text = sect.instance_variable_get :@title
    text, source_modified = handle_inline_stem sect, text, image_output_dir, image_target_dir
    sect.title = text if source_modified
  end

  def handle_inline_stem(node, text, image_output_dir, image_target_dir)
    document = node.document
    source_modified = false

    return [text, source_modified] unless document.attr? 'stem'

    to_html = document.basebackend? 'html'

    default_equation_type = document.attr('stem').include?('tex') ? :latexmath : :asciimath

    # TODO skip passthroughs in the source (e.g., +stem:[x^2]+)
    if text && text.include?(':') && (text.include?('stem:') || text.include?('math:'))
      text = text.gsub(StemInlineMacroRx) do
        if (m = $~)[0].start_with? '\\'
          next m[0][1..-1]
        end

        next '' if (eq_data = m[3].rstrip).empty?

        equation_type = default_equation_type if (equation_type = m[1].to_sym) == :stem
        if equation_type == :asciimath
          eq_data = AsciiMath.parse(eq_data).to_latex
        else # :latexmath
          eq_data = eq_data.gsub('\]', ']')
          subs = m[2].nil_or_empty? ? (to_html ? [:specialcharacters] : []) : (node.resolve_pass_subs m[2])
          eq_data = node.apply_subs eq_data, subs unless subs.empty?
        end

        source_modified = true
        desired_font_size = get_desired_font_size(node, true)
        puts "DEBUG: Desired font size: #{desired_font_size}"

        img_target, img_file = generate_svg eq_data, nil, true, desired_font_size, image_output_dir, image_target_dir

        svg_width = get_svg_width(img_file)
        puts "SVG Width: #{svg_width} units (likely pixels)"

        pdf_line_width = get_pdf_line_width(document)
        puts "PDF Line Width: #{pdf_line_width} pt"

        if svg_width > 0
          font_size = node.attr('font-size', 10).to_f
          ratio = 6 * svg_width / pdf_line_width / 12 * font_size * 100
          puts "DEBUG: Ratio of SVG width to PDF line width: #{ratio} to match font size #{font_size}"
          %(image:#{img_target}[width=#{ratio}%])
        else
          puts "Could not determine SVG width for #{img_target}"
          %(image:#{img_target}[])
        end
      end
    end

    [text, source_modified]
  end

  def get_desired_font_size(node, is_inline)
    document = node.document
    base_font_size = (document.attributes['base-font-size'] || 10).to_f
    if is_inline
      base_font_size
    else
      base_font_size * 1.2
    end
  end

  def get_svg_width(svg_file)
    puts "DEBUG: Attempting to get SVG width for #{svg_file}"
    return 0 unless File.exist?(svg_file)
    puts "DEBUG: Getting SVG width for #{svg_file}"
    svg_content = File.read(svg_file)
    doc = Nokogiri::XML(svg_content)
    svg_element = doc.at('svg')

    width = svg_element['width']&.to_f || 0
    if width.zero? && svg_element['viewBox']
      viewbox = svg_element['viewBox'].split
      width = viewbox[2].to_f
    end
    width
  end

  def get_pdf_line_width(document)
    # Default A4 page width in points (595 pt)
    page_width = document.attr('pdf-page-size', '595').to_f

    # Get margins (default 36 pt if not specified)
    margin_left = document.attr('pdf-margin-left', '36').to_f
    margin_right = document.attr('pdf-margin-right', '36').to_f

    # Calculate usable width
    page_width - margin_left - margin_right
  end

  def generate_svg(equ_data, equ_id, equ_inline, font_size, image_output_dir, image_target_dir)
    input = equ_data #equ_inline ? %($#{equ_data}$) : %($$#{equ_data}$$)
    unless equ_id
      equ_id = %(stem-#{::Digest::MD5.hexdigest input})
    end
    image_ext = %(.svg)
    img_target = %(#{equ_id}#{image_ext})
    img_file = ::File.join image_output_dir, img_target
    puts "DEBUG: Generating SVG for equation #{equ_id} with expression: #{input[0..20]}... to #{img_file}"

    js_script = File.join(File.dirname(__FILE__), '../bin/render.js')
    cmd = "node #{js_script} #{font_size} \"#{escape_expression(input)}\" #{img_file}"
    puts "DEBUG: Executing MathJax command: #{cmd}"
    stdout, stderr, status = Open3.capture3(cmd)
    unless status.success?
      puts "DEBUG: MathJax rendering failed for '#{input[0..20]}...': #{stderr}"
      return nil
    end
    puts "DEBUG: Generated SVG at #{img_file}"

    img_target = ::File.join image_target_dir, img_target unless image_target_dir == '.'
    [img_target, img_file]
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

  def create_inline_image_node(node, document, svg_file, width, height)
    attributes = {
      "width" => width.round(2).to_s,
      "height" => height.round(2).to_s,
      "alt" => "Math expression"
    }
    image_node = Asciidoctor::Inline.new(document, "image", svg_file, type: "image", attributes: attributes)
    image_node
  end

  def escape_expression(expr)
    expr.gsub('"', '\\"')
  end
end

Asciidoctor::Extensions.register do
  puts "DEBUG: Registering MathJaxTreeProcessor extension"
  tree_processor MathJaxTreeProcessor
end
