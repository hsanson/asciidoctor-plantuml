# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'asciidoctor_plantuml/version'

Gem::Specification.new do |s|
  s.name = 'asciidoctor-plantuml'
  s.version = Asciidoctor::PlantUML::VERSION
  s.authors = ['Horacio Sanson']
  s.email = ['hsanson@gmail.com']
  s.description = 'Asciidoctor PlantUML extension'
  s.summary = 'Asciidoctor support for PlantUML diagrams.'
  s.platform = Gem::Platform::RUBY
  s.homepage = 'https://github.com/hsanson/asciidoctor-plantuml'
  s.license = 'MIT'
  s.files = `git ls-files -z -- */* {LICENSE,README,Rakefile}*`.split "\x0"

  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 2.6'
  s.metadata['rubygems_mfa_required'] = 'true'
end
