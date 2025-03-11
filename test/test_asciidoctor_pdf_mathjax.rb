# frozen_string_literal: true

require 'minitest/autorun'
require 'asciidoctor'
require 'asciidoctor-pdf'
require_relative '../lib/asciidoctor-pdf-mathjax'

Minitest::Test = MiniTest::Unit::TestCase unless defined? Minitest::Test

class TestAsciidoctorPdfMathjax < Minitest::Test
  def setup
    system("npm install --silent mathjax-node")
  end

  def teardown
    system("npm remove --silent mathjax-node")
  end

  PDF_COMPARISON_DIFFERENT_MESSAGE = 'PDF files are different'
  TESTCASES = %w[asciimath stem_asciimath latex stem_latex]

  TESTCASES.each do |testcase|
    define_method("test_that_conversion_of_#{testcase}_works") do
      verify_conversion_of(testcase)
    end
  end

  def verify_conversion_of(case_name)
    received_pdf_file = "./test/verification/#{case_name}.received.pdf"
    verified_pdf_file = "./test/verification/#{case_name}.verified.pdf"
    diff_file = "./test/verification/#{case_name}.diff.pdf"
    adoc_file_path = "./test/verification/#{case_name}.adoc"
    adoc_file = open(adoc_file_path)
    attributes = {
      'root' => "#{Dir.pwd}/test/",
    }
    Asciidoctor.convert adoc_file, to_file: received_pdf_file, safe: :safe, backend: 'pdf', require: 'asciidoctor-pdf-mathjax', attributes: attributes

    assert File.exist?(received_pdf_file), 'PDF file was not created'
    diff_command = "diff-pdf --output-diff=#{diff_file} #{verified_pdf_file} #{received_pdf_file}"
    diff_result = system(diff_command)
    if diff_result
      assert_equal 0, $?&.exitstatus, PDF_COMPARISON_DIFFERENT_MESSAGE
    elsif diff_result.nil?
      flunk "diff-pdf is not installed"
    else
      full_diff_path = File.expand_path(diff_file)
      flunk PDF_COMPARISON_DIFFERENT_MESSAGE + " (see file://#{full_diff_path})"
    end
  ensure
    adoc_file&.close
    if diff_result
      File.delete(received_pdf_file)
      File.delete(diff_file)
    end
  end
end
