# frozen_string_literal: true

require 'asciidoctor'
require 'asciidoctor/extensions'
require_relative 'asciidoctor_plantuml/plantuml'

Asciidoctor::Extensions.register do
  block Asciidoctor::PlantUml::BlockProcessor, :plantuml
  block_macro Asciidoctor::PlantUml::BlockMacroProcessor, :plantuml
end
