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
  s.test_files = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 2.6'
  s.add_development_dependency 'bundler', '~> 2.2'
  s.add_development_dependency 'nokogiri', '~> 1.13.4'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rubocop', '~> 1.28'
  s.add_development_dependency 'test-unit', '~> 3.5'
  s.add_runtime_dependency 'asciidoctor', '>= 2.0.17', '< 3.0.0'
  s.metadata['rubygems_mfa_required'] = 'true'
end
