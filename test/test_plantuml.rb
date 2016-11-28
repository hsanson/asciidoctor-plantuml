require "test/unit"
require "asciidoctor"
require "stringio"
require "nokogiri"
require "asciidoctor-plantuml"

DOC_BASIC = <<-eos
= Hello PlantUML!

[plantuml, format="png", test="true"]
User -> (Start)
User --> (Use the application) : Label
eos

DOC_BASIC2 = <<-eos
= Hello PlantUML!

[plantuml, format="png", test="true"]
@startuml
User -> (Start)
User --> (Use the application) : Label
@enduml
eos

DOC_ID = <<-eos
= Hello PlantUML!

[plantuml, format="png", test="true", id="myId"]
User -> (Start)
User --> (Use the application) : Label
eos

DOC_DIM = <<-eos
= Hello PlantUML!

[plantuml, format="png", test="true", width="100px", height="50px"]
User -> (Start)
User --> (Use the application) : Label
eos

DOC_ALT = <<-eos
= Hello PlantUML!

[plantuml, format="png", test="true", alt="alt"]
User -> (Start)
User --> (Use the application) : Label
eos

DOC_BAD_FORMAT = <<-eos
= Hello PlantUML!

[plantuml, format="jpg", test="true"]
User -> (Start)
User --> (Use the application) : Label
eos

DOC_MULTI = <<-eos
= Hello PlantUML!

[plantuml, format="png", test="true"]
User -> (Start)
User --> (Use the application) : Label

[plantuml, format="txt", test="true"]
User -> (Start)
User --> (Use the application) : Label
eos

class PlantUmlTest < Test::Unit::TestCase

  GENURL = "http://localhost:8080/plantuml/png/U9npA2v9B2efpStX2YrEBLBGjLFG20Q9Q4Bv804WIw4a8rKXiQ0W9pCviIGpFqzJmKh19p4fDOVB8JKl1QWT05kd5wq0"

  def test_plantuml_block_processor

    html = ::Asciidoctor.convert(StringIO.new(DOC_BASIC), backend: "html5")
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL, element["src"]
  end

  def test_plantuml_block_processor2
    html = ::Asciidoctor.convert(StringIO.new(DOC_BASIC2), backend: "html5")
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL, element["src"]
  end

  def test_plantuml_id_attribute

    html = ::Asciidoctor.convert(StringIO.new(DOC_ID), backend: "html5")
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1
    element = elements.first

    assert_equal "myId", element["id"]

  end

  def test_plantuml_dimension_attribute

    html = ::Asciidoctor.convert(StringIO.new(DOC_DIM), backend: "html5")
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1
    element = elements.first

    assert_equal "100px", element["width"]
    assert_equal "50px", element["height"]

  end

  def test_plantuml_alt_attribute

    html = ::Asciidoctor.convert(StringIO.new(DOC_ALT), backend: "html5")
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1
    element = elements.first

    assert_equal "alt", element["alt"]

  end

  def test_should_show_bad_format
    html = ::Asciidoctor.convert(StringIO.new(DOC_BAD_FORMAT), backend: "html5")

    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')
    assert_equal elements.size, 0

    elements = page.css('div.plantuml')
    assert_equal elements.size, 1
  end

  def test_plantuml_multiple

    html = ::Asciidoctor.convert(StringIO.new(DOC_MULTI), backend: "html5")
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 2

  end

end
