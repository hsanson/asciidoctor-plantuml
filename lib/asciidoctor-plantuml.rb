require 'asciidoctor'
require 'asciidoctor/extensions'
require_relative 'asciidoctor-plantuml/plantuml'

Asciidoctor::Extensions.register do
  block Asciidoctor::PlantUml::BlockProcessor, :plantuml
end
