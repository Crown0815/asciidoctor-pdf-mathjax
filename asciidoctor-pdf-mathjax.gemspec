Gem::Specification.new do |spec|
  spec.name          = 'asciidoctor-pdf-mathjax'
  spec.version = '0.0.1'
  spec.authors       = ['Crown0815']
  spec.summary       = 'AsciiDoctor extension to render STEM fields using MathJax SVG'
  spec.description   = 'Converts STEM blocks and inline macros to SVG images using MathJax-node for AsciiDoctor PDF.'
  spec.homepage      = 'https://github.com/Crown0815/asciidoctor-pdf-mathjax'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7'

  spec.files = Dir['lib/**/*', 'bin/**/*']
  spec.executables   = ['render.js']
  spec.require_paths = ['lib']

  spec.add_dependency 'asciidoctor', '~> 2.0'
  spec.add_dependency 'asciidoctor-pdf', '~> 2.3', '>= 2.3.19'
  spec.add_dependency 'nokogiri', '~> 1.18', '>= 1.18.3'
  spec.add_dependency 'asciimath', '~> 2.0', '>= 2.0.6'
  spec.add_dependency 'bigdecimal', '~> 3.0' if RUBY_VERSION > '3.3'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'logger', '~> 1.4'

  spec.post_install_message = <<~MSG
    Thank you for installing #{spec.name}!
    Note: This gem requires MathJax-Node for full functionality (e.g., LaTeX rendering).
    If you haven't installed it, run:
      npm install -g mathjax-node
    See the README for details.
  MSG
end
