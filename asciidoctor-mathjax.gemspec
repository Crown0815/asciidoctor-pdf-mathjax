Gem::Specification.new do |spec|
  spec.name          = 'asciidoctor-mathjax'
  spec.version       = '0.1.0'
  spec.authors       = ['Your Name']
  spec.email         = ['your.email@example.com']
  spec.summary       = 'AsciiDoctor extension to render STEM fields using MathJax SVG'
  spec.description   = 'Converts STEM blocks and inline macros to SVG images using MathJax-node for AsciiDoctor PDF.'
  spec.homepage      = 'https://github.com/yourusername/asciidoctor-mathjax'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.0'

  spec.files = Dir['lib/**/*', 'bin/**/*']
  spec.executables   = ['render.js']
  spec.require_paths = ['lib']

  spec.add_dependency 'asciidoctor', '~> 2.0'
  spec.add_development_dependency 'bundler', '~> 2.0'
end
