Gem::Specification.new do |spec|
  spec.name          = 'asciidoctor-mathjax'
  spec.version       = '0.1.0'
  spec.authors       = ['Your Name']
  spec.email         = ['your.email@example.com']
  spec.summary       = 'AsciiDoctor extension to render STEM fields using MathJax SVG'
  spec.description   = 'Converts STEM blocks and inline macros to SVG images using MathJax-node for AsciiDoctor PDF.'
  spec.homepage      = 'https://github.com/yourusername/asciidoctor-mathjax'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7'

  spec.files = Dir['lib/**/*', 'bin/**/*']
  spec.executables   = ['render.js']
  spec.require_paths = ['lib']

  spec.add_dependency 'asciidoctor', '~> 2.0'
  spec.add_dependency 'asciidoctor-pdf', '~> 2.3', '>= 2.3.19'
  spec.add_dependency 'nokogiri', '~> 1.18', '>= 1.18.3'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
end
