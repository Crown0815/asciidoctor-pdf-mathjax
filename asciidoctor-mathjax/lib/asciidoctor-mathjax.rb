require 'asciidoctor'
require 'asciidoctor_mathjax/preprocessor'

puts "DEBUG: Loading asciidoctor_mathjax_extension"

Asciidoctor::Extensions.register do
  puts "DEBUG: Registering MathJax extension"
  preprocessor MathJaxPreprocessor
end
