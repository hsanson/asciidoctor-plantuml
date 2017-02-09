require "test/unit"
require "asciidoctor"
require "stringio"
require "nokogiri"
require "asciidoctor-plantuml"

DOC_BASIC = <<-eos
= Hello PlantUML!

[plantuml, format="png"]
----
User -> (Start)
User --> (Use the application) : Label
----
eos

DOC_BASIC2 = <<-eos
= Hello PlantUML!

[plantuml, format="png"]
----
@startuml
User -> (Start)
User --> (Use the application) : Label
@enduml
----
eos

DOC_BASIC3 = <<-eos
= Hello Compound PlantUML!

[plantuml, format="png"]
----
[COMP1]
[COMP2]
[COMP1] -> [COMP2]
[COMP2] --> [COMP3]
----
eos

DOC_ID = <<-eos
= Hello PlantUML!

[plantuml, format="png", id="myId"]
----
User -> (Start)
User --> (Use the application) : Label
----
eos

DOC_DIM = <<-eos
= Hello PlantUML!

[plantuml, format="png", width="100px", height="50px"]
----
User -> (Start)
User --> (Use the application) : Label
----
eos

DOC_ALT = <<-eos
= Hello PlantUML!

[plantuml, format="png", alt="alt"]
----
User -> (Start)
User --> (Use the application) : Label
----
eos

DOC_BAD_FORMAT = <<-eos
= Hello PlantUML!

[plantuml, format="jpg"]
----
User -> (Start)
User --> (Use the application) : Label
----
eos

DOC_MULTI = <<-eos
= Hello PlantUML!
:listing-caption: Diagram

[#fig-1,reftext='{listing-caption} {counter:refnum}']
[plantuml, format="png"]
.PNG Format
----
User -> (Start)
User --> (Use the application) : Label
----

[#fig-2,reftext='{listing-caption} {counter:refnum}']
[plantuml, format="png"]
.PNG Format 2
----
User -> (Start)
User --> (Use the application) : Label
----

[#fig-3,reftext='{listing-caption} {counter:refnum}']
[plantuml, format="txt"]
.TXT Format
----
User -> (Start)
User --> (Use the application) : Label
----
eos

DOC_TXT = <<-eos
= Hello PlantUML!

[plantuml, format="txt"]
----
User -> (Start)
User --> (Use the application) : Label
----
eos

class PlantUmlTest < Test::Unit::TestCase

  GENURL = "http://localhost:8080/plantuml/png/U9npA2v9B2efpStX2YrEBLBGjLFG20Q9Q4Bv804WIw4a8rKXiQ0W9pCviIGpFqzJmKh19p4fDOVB8JKl1QWT05kd5wq0"
  GENURL2 = "http://localhost:8080/plantuml/png/U9npA2v9B2efpStXYdRszmqmZ8NGHh4mleAkdGAAa15G22Pc7Clba9gN0jGE00W75Cm0"

  def setup
    Asciidoctor::PlantUml.configure do |c|
      c.url = "http://localhost:8080/plantuml"
      c.txt_enable = true
    end
  end

  def test_plantuml_block_processor

    html = ::Asciidoctor.convert(StringIO.new(DOC_BASIC), backend: "html5")
    page = Nokogiri::HTML(html)

    assert_equal page.css('div.imageblock').size, 1

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL, element["src"]
  end

  def test_plantuml_block_processor2
    html = ::Asciidoctor.convert(StringIO.new(DOC_BASIC2), backend: "html5")
    page = Nokogiri::HTML(html)

    assert_equal page.css('div.imageblock').size, 1

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL, element["src"]
  end

  def test_plantuml_block_processor3
    html = ::Asciidoctor.convert(StringIO.new(DOC_BASIC3), backend: "html5")
    page = Nokogiri::HTML(html)

    assert_equal page.css('div.imageblock').size, 1

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL2, element["src"]
  end

  def test_plantuml_id_attribute

    html = ::Asciidoctor.convert(StringIO.new(DOC_ID), backend: "html5")
    page = Nokogiri::HTML(html)

    assert_equal page.css('div.imageblock').size, 1

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1
    element = elements.first

    assert_equal "myId", element["id"]

  end

  def test_plantuml_dimension_attribute

    html = ::Asciidoctor.convert(StringIO.new(DOC_DIM), backend: "html5")
    page = Nokogiri::HTML(html)

    assert_equal page.css('div.imageblock').size, 1

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1
    element = elements.first

    assert_equal "100px", element["width"]
    assert_equal "50px", element["height"]

  end

  def test_plantuml_alt_attribute

    html = ::Asciidoctor.convert(StringIO.new(DOC_ALT), backend: "html5")
    page = Nokogiri::HTML(html)

    assert_equal page.css('div.imageblock').size, 1

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1
    element = elements.first

    assert_equal "alt", element["alt"]

  end

  def test_should_show_bad_format
    html = ::Asciidoctor.convert(StringIO.new(DOC_BAD_FORMAT), backend: "html5")

    page = Nokogiri::HTML(html)

    assert_equal page.css('div.listingblock').size, 1

    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1

  end

  def test_plantuml_multiple

    html = ::Asciidoctor.convert(StringIO.new(DOC_MULTI), backend: "html5")
    page = Nokogiri::HTML(html)

    assert_equal page.css('div.imageblock').size, 2
    assert_equal page.css('div.listingblock').size, 1

    elements = page.css('img.plantuml')
    assert_equal elements.size, 2

    elements = page.css('.plantuml-error')
    assert_equal elements.size, 0

    # Check the blocks have captions
    elements = page.css('div.title')
    assert_equal elements.size, 3

    # Check the caption counter works as expected.
    assert_equal elements[0].text, "Diagram 1. PNG Format"
    assert_equal elements[1].text, "Diagram 2. PNG Format 2"
    assert_equal elements[2].text, "Diagram 3. TXT Format"
  end

  def test_plantuml_bad_server

    Asciidoctor::PlantUml.configure do |c|
      c.url = "http://nonexistent.com/plantuml"
    end

    html = ::Asciidoctor.convert(StringIO.new(DOC_MULTI), backend: "html5")
    page = Nokogiri::HTML(html)

    assert_equal page.css('div.imageblock').size, 3

    elements = page.css('img.plantuml')
    assert_equal elements.size, 3

    elements = page.css('.plantuml-error')
    assert_equal elements.size, 0
  end

  def test_plantuml_invalid_uri

    Asciidoctor::PlantUml.configure do |c|
      c.url = "ftp://test.com"
    end

    html = ::Asciidoctor.convert(StringIO.new(DOC_BASIC), backend: "html5")
    page = Nokogiri::HTML(html)
    assert_equal page.css('div.listingblock').size, 1
    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1
  end

  def test_plantuml_nil_uri

    Asciidoctor::PlantUml.configure do |c|
      c.url = nil
    end

    html = ::Asciidoctor.convert(StringIO.new(DOC_BASIC), backend: "html5")
    page = Nokogiri::HTML(html)
    assert_equal page.css('div.listingblock').size, 1
    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1
  end

  def test_plantuml_empty_uri

    Asciidoctor::PlantUml.configure do |c|
      c.url = ""
    end

    html = ::Asciidoctor.convert(StringIO.new(DOC_BASIC), backend: "html5")
    page = Nokogiri::HTML(html)
    assert_equal page.css('div.listingblock').size, 1
    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1
  end

  def test_disable_txt

    Asciidoctor::PlantUml.configure do |c|
      c.url = "http://localhost:8080/plantuml"
      c.txt_enable = false
    end

    html = ::Asciidoctor.convert(StringIO.new(DOC_TXT), backend: "html5")
    page = Nokogiri::HTML(html)
    assert_equal page.css('div.listingblock').size, 1
    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1

  end
end
