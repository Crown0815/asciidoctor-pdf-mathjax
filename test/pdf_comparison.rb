# frozen_string_literal: true

require 'pdf-reader'

module PdfComparison
  module_function

  # Prawn rewrites the document ID and timestamps on every run. Pixel comparison also
  # depends on a native renderer. Page content, embedded font programs, and XObjects
  # stay the same across operating systems, so those are the approval baseline.
  def difference(verified_pdf_file, received_pdf_file)
    verified = PDF::Reader.new(verified_pdf_file)
    received = PDF::Reader.new(received_pdf_file)
    unless verified.page_count == received.page_count
      return "page count #{received.page_count} != #{verified.page_count}"
    end

    verified.pages.zip(received.pages).each_with_index do |(expected, actual), index|
      difference = page_difference(expected, actual, index + 1)
      return difference if difference
    end
    nil
  end

  def page_difference(expected, actual, number)
    expected_box = media_box(expected)
    actual_box = media_box(actual)
    return "page #{number} MediaBox #{actual_box} != #{expected_box}" if actual_box != expected_box

    expected_content = expected.raw_content.to_s
    actual_content = actual.raw_content.to_s
    unless expected_content == actual_content
      index = first_mismatch(expected_content, actual_content)
      return "page #{number} content differs at byte #{index} " \
             "(#{actual_content.bytesize} bytes, baseline #{expected_content.bytesize}): " \
             "#{content_window(actual_content, index)} != #{content_window(expected_content, index)}"
    end

    xobject_difference = named_bytes_difference(xobject_streams(expected), xobject_streams(actual))
    return "page #{number} XObject #{xobject_difference}" if xobject_difference

    font_difference = named_bytes_difference(font_streams(expected), font_streams(actual))
    return "page #{number} font #{font_difference}" if font_difference

    nil
  end

  def media_box(page)
    Array(page.page_object[:MediaBox]).map { |value| format('%.4f', value.to_f) }
  end

  def xobject_streams(page)
    page.xobjects.sort_by { |name, _| name.to_s }.map do |name, stream|
      [name.to_s, stream.respond_to?(:data) ? stream.data.to_s : '']
    end
  end

  def font_streams(page)
    page.fonts.sort_by { |name, _| name.to_s }.map do |name, font|
      [name.to_s, embedded_font_bytes(font).join]
    end
  end

  def embedded_font_bytes(font)
    return [] unless font.is_a?(Hash)

    bytes = []
    descriptor = font[:FontDescriptor]
    if descriptor.is_a?(Hash)
      %i[FontFile FontFile2 FontFile3].each do |key|
        stream = descriptor[key]
        bytes << stream.data.to_s if stream.respond_to?(:data)
      end
    end
    Array(font[:DescendantFonts]).each do |descendant|
      bytes.concat(embedded_font_bytes(descendant))
    end
    bytes
  end

  def named_bytes_difference(expected, actual)
    expected_names = expected.map(&:first)
    actual_names = actual.map(&:first)
    return "names #{actual_names.inspect} != #{expected_names.inspect}" if actual_names != expected_names

    expected.zip(actual).each do |(_, expected_data), (name, actual_data)|
      next if expected_data == actual_data

      return "#{name} differs (#{actual_data.bytesize} bytes, baseline #{expected_data.bytesize})"
    end
    nil
  end

  def first_mismatch(expected, actual)
    limit = [expected.bytesize, actual.bytesize].min
    index = (0...limit).find { |i| expected.getbyte(i) != actual.getbyte(i) }
    index.nil? && expected.bytesize != actual.bytesize ? limit : index
  end

  def content_window(text, index)
    text.byteslice([index - 40, 0].max, 80).inspect
  end
end