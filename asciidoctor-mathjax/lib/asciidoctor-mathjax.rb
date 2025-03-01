require 'asciidoctor-pdf' unless Asciidoctor::Converter.for 'pdf'

class AsciidoctorPDFExtensions < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def convert_stem node
    puts "DEBUG: arrange_block"
    arrange_block node do |extent|
      puts "DEBUG: add_dest_for_block"
      add_dest_for_block node if node.id
      puts "DEBUG: tare_first_page_content_stream"
      tare_first_page_content_stream { theme_fill_and_stroke_block :code, extent, caption_node: node }
      puts "DEBUG: add_block_border"
      pad_box @theme.code_padding, node do
        theme_font :code do
          typeset_formatted_text [text: (guard_indentation node.content), color: @font_color],
            (calc_line_metrics @base_line_height),
            bottom_gutter: @bottom_gutters[-1][node]
        end
      end
    end
    theme_margin :block, :bottom, (next_enclosed_block node)
  end

end
