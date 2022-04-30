# frozen_string_literal: true

require 'test/unit'
require 'asciidoctor'
require 'stringio'
require 'nokogiri'
require 'asciidoctor-plantuml'

DOC_BASIC = <<~ENDOFSTRING
  = Hello PlantUML!

  [plantuml, format="png"]
  .Title Of this
  ----
  User -> (Start)
  User --> (Use the application) : Label
  ----
ENDOFSTRING

DOC_BASIC_LITERAL = <<~ENDOFSTRING
  = Hello PlantUML!

  [plantuml, format="png"]
  .Title Of this
  ....
  User -> (Start)
  User --> (Use the application) : Label
  ....
ENDOFSTRING

DOC_BASIC2 = <<~ENDOFSTRING
  = Hello PlantUML!

  [plantuml, format="png"]
  .Title Of this
  [[fig-xref]]
  ----
  @startuml
  User -> (Start)
  User --> (Use the application) : Label
  @enduml
  ----
ENDOFSTRING

DOC_BASIC2_LITERAL = <<~ENDOFSTRING
  = Hello PlantUML!

  [plantuml, format="png"]
  .Title Of this
  [[fig-xref]]
  ....
  @startuml
  User -> (Start)
  User --> (Use the application) : Label
  @enduml
  ....
ENDOFSTRING

DOC_BASIC3 = <<~ENDOFSTRING
  = Hello Compound PlantUML!

  [plantuml, format="png"]
  ----
  [COMP1]
  [COMP2]
  [COMP1] -> [COMP2]
  [COMP2] --> [COMP3]
  ----
ENDOFSTRING

DOC_BASIC3_LITERAL = <<~ENDOFSTRING
  = Hello Compound PlantUML!

  [plantuml, format="png"]
  ....
  [COMP1]
  [COMP2]
  [COMP1] -> [COMP2]
  [COMP2] --> [COMP3]
  ....
ENDOFSTRING

DOC_ID = <<~ENDOFSTRING
  = Hello PlantUML!

  [plantuml, format="png", id="myId"]
  ----
  User -> (Start)
  User --> (Use the application) : Label
  ----
ENDOFSTRING

DOC_DIM = <<~ENDOFSTRING
  = Hello PlantUML!

  [plantuml, format="png", width="100px", height="50px"]
  ----
  User -> (Start)
  User --> (Use the application) : Label
  ----
ENDOFSTRING

DOC_ALT = <<~ENDOFSTRING
  = Hello PlantUML!

  [plantuml, format="png", alt="alt"]
  ----
  User -> (Start)
  User --> (Use the application) : Label
  ----
ENDOFSTRING

DOC_BAD_FORMAT = <<~ENDOFSTRING
  = Hello PlantUML!

  [plantuml, format="jpg"]
  ----
  User -> (Start)
  User --> (Use the application) : Label
  ----
ENDOFSTRING

DOC_MULTI = <<~ENDOFSTRING
  = Hello PlantUML!

  [plantuml, format="png"]
  ----
  User -> (Start)
  User --> (Use the application) : Label
  ----

  [plantuml, format="png"]
  ----
  User -> (Start)
  User --> (Use the application) : Label
  ----

  [plantuml, format="txt"]
  ----
  User -> (Start)
  User --> (Use the application) : Label
  ----
ENDOFSTRING

DOC_MULTI_LITERAL = <<~ENDOFSTRING
  = Hello PlantUML!

  [plantuml, format="png"]
  ....
  User -> (Start)
  User --> (Use the application) : Label
  ....

  [plantuml, format="png"]
  ....
  User -> (Start)
  User --> (Use the application) : Label
  ....

  [plantuml, format="txt"]
  ....
  User -> (Start)
  User --> (Use the application) : Label
  ....
ENDOFSTRING

DOC_TXT = <<~ENDOFSTRING
  = Hello PlantUML!

  [plantuml, format="txt"]
  ----
  User -> (Start)
  User --> (Use the application) : Label
  ----
ENDOFSTRING

DOC_SVG = <<~ENDOFSTRING
  = Hello PlantUML!

  [plantuml, format="svg"]
  ----
  User -> (Start)
  User --> (Use the application) : Label
  ----
ENDOFSTRING

DOC_BLOCK_MACRO = <<~ENDOFSTRING
  = Hello PlantUML!

  .Title Of this
  plantuml::test/fixtures/test.puml[]
ENDOFSTRING

DOC_BLOCK_MACRO_MISSING_FILE = <<~ENDOFSTRING
  = Hello PlantUML!

  .Title Of this
  plantuml::test/fixtures/missing.puml[]
ENDOFSTRING

DOC_BLOCK_MACRO_INSECURE_FILE = <<~ENDOFSTRING
  = Hello PlantUML!

  .Title Of this
  plantuml::/etc/passwd[]
ENDOFSTRING

DOC_SUBS_ATTRIBUTES = <<~ENDOFSTRING
  = Hello PlantUML!
  :text: Label

  [plantuml, format="png", subs="attributes+"]
  .Title Of this
  ----
  User -> (Start)
  User --> (Use the application) : {text}
  ----
ENDOFSTRING

DOC_CONFIG_INCLUDE = <<~ENDOFSTRING
  = Hello PlantUML!
  :plantuml-include: test/fixtures/config.puml

  [plantuml, format="png"]
  .Title Of this
  ----
  User -> (Start)
  User --> (Use the application) : Label
  ----
ENDOFSTRING

DOC_CONFIG_INCLUDE_MISSING_FILE = <<~ENDOFSTRING
  = Hello PlantUML!
  :plantuml-include: test/fixtures/missing.puml

  [plantuml, format="png"]
  .Title Of this
  ----
  User -> (Start)
  User --> (Use the application) : Label
  ----
ENDOFSTRING

DOC_CONFIG_INCLUDE_INSECURE_FILE = <<~ENDOFSTRING
  = Hello PlantUML!
  :plantuml-include: /etc/passwd

  [plantuml, format="png"]
  .Title Of this
  ----
  User -> (Start)
  User --> (Use the application) : Label
  ----
ENDOFSTRING

DOC_CONFIG_INCLUDE_MACRO_BLOCK = <<~ENDOFSTRING
  = Hello PlantUML!
  :plantuml-include: test/fixtures/config.puml

  [plantuml, format="png"]
  plantuml::test/fixtures/test.puml[]
ENDOFSTRING

class PlantUmlTest < Test::Unit::TestCase
  GENURL = 'http://localhost:8080/plantuml/png/U9npA2v9B2efpStX2YrEBLBGjLFG20Q9Q4Bv804WIw4a8rKXiQ0W9pCviIGpFqzJmKh19p4fDOVB8JKl1QWT05kd5wq0'
  GENURL2 = 'http://localhost:8080/plantuml/png/U9npA2v9B2efpStXYdRszmqmZ8NGHh4mleAkdGAAa15G22Pc7Clba9gN0jGE00W75Cm0'
  GENURL_ENCODING = 'http://localhost:8080/plantuml/png/~1U9npA2v9B2efpStX2YrEBLBGjLFG20Q9Q4Bv804WIw4a8rKXiQ0W9pCviIGpFqzJmKh19p4fDOVB8JKl1QWT05kd5wq0'
  GENURL_CONFIG = 'http://localhost:8080/plantuml/png/~1U9nDZJ4Emp08HVUSWh4PUe4ELQIktQeUW3YeiMA31NZexKEg3bc-Fly1Vp97zLxBO5lcXeeLgh2aLQKIk7OwaHdJzb7fl3oaY0P6ja34Vjeo_nOArPn-dzz62jSxN5v7r_YVZo0S-4g0hPMSqBFm23Tuuanbc8YNEDy1SzOwlG00'
  SVGGENURL = 'http://localhost:8080/plantuml/svg/~1U9npA2v9B2efpStX2YrEBLBGjLFG20Q9Q4Bv804WIw4a8rKXiQ0W9pCviIGpFqzJmKh19p4fDOVB8JKl1QWT05kd5wq0'

  def setup
    Asciidoctor::PlantUml.configure do |c|
      c.url = 'http://localhost:8080/plantuml'
      c.txt_enable = true
      c.png_enable = true
      c.svg_enable = true
    end
  end

  def test_plantuml_block_processor
    html = ::Asciidoctor.convert(StringIO.new(DOC_BASIC), backend: 'html5')
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL, element['src']
  end

  def test_plantuml_block_literal_processor
    html = ::Asciidoctor.convert(
      StringIO.new(DOC_BASIC_LITERAL), backend: 'html5'
    )
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL, element['src']
  end

  def test_plantuml_block_processor2
    html = ::Asciidoctor.convert(
      StringIO.new(DOC_BASIC2), backend: 'html5'
    )
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL, element['src']
  end

  def test_plantuml_block_literal_processor2
    html = ::Asciidoctor.convert(
      StringIO.new(DOC_BASIC2_LITERAL), backend: 'html5'
    )
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL, element['src']
  end

  def test_plantuml_block_processor3
    html = ::Asciidoctor.convert(StringIO.new(DOC_BASIC3), backend: 'html5')
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL2, element['src']
  end

  def test_plantuml_block_literal_processor3
    html = ::Asciidoctor.convert(
      StringIO.new(DOC_BASIC3_LITERAL), backend: 'html5'
    )
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL2, element['src']
  end

  def test_plantuml_block_processor_encoding
    Asciidoctor::PlantUml.configure do |c|
      c.encoding = 'deflate'
    end

    html = ::Asciidoctor.convert(StringIO.new(DOC_BASIC), backend: 'html5')
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL_ENCODING, element['src']
  end

  def test_plantuml_block_macro_processor
    html = ::Asciidoctor.convert(StringIO.new(DOC_BLOCK_MACRO), backend: 'html5')
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL, element['src']
  end

  def test_should_show_file_error
    html = ::Asciidoctor.convert(StringIO.new(DOC_BLOCK_MACRO_MISSING_FILE), backend: 'html5', safe: :secure)
    page = Nokogiri::HTML(html)

    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1
    assert_includes html, 'No such file or directory'
  end

  def test_should_show_insecure_error
    html = ::Asciidoctor.convert(StringIO.new(DOC_BLOCK_MACRO_INSECURE_FILE), backend: 'html5', safe: :secure)
    page = Nokogiri::HTML(html)

    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1
    assert_includes html, 'is outside of jail'
  end

  def test_plantuml_subs_attributes
    html = ::Asciidoctor.convert(StringIO.new(DOC_SUBS_ATTRIBUTES), backend: 'html5')
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL_ENCODING, element['src']
  end

  def test_plantuml_config_include
    html = ::Asciidoctor.convert(StringIO.new(DOC_CONFIG_INCLUDE), backend: 'html5', safe: :secure)
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL_CONFIG, element['src']
  end

  def test_plantuml_config_include_missing_file
    html = ::Asciidoctor.convert(StringIO.new(DOC_CONFIG_INCLUDE_MISSING_FILE), backend: 'html5')
    page = Nokogiri::HTML(html)

    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1
    assert_includes html, 'No such file or directory'
  end

  def test_plantuml_config_include_insecure_file
    html = ::Asciidoctor.convert(StringIO.new(DOC_CONFIG_INCLUDE_INSECURE_FILE), backend: 'html5', safe: :secure)
    page = Nokogiri::HTML(html)

    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1
    assert_includes html, 'is outside of jail'
  end

  def test_plantuml_config_include_macro_block
    html = ::Asciidoctor.convert(StringIO.new(DOC_CONFIG_INCLUDE_MACRO_BLOCK), backend: 'html5', safe: :secure)
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1

    element = elements.first

    assert_equal GENURL_CONFIG, element['src']
  end

  def test_plantuml_id_attribute
    html = ::Asciidoctor.convert(StringIO.new(DOC_ID), backend: 'html5')
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1
    element = elements.first

    assert_equal 'myId', element['id']
  end

  def test_plantuml_dimension_attribute
    html = ::Asciidoctor.convert(StringIO.new(DOC_DIM), backend: 'html5')
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1
    element = elements.first

    assert_equal '100px', element['width']
    assert_equal '50px', element['height']
  end

  def test_plantuml_alt_attribute
    html = ::Asciidoctor.convert(StringIO.new(DOC_ALT), backend: 'html5')
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')

    assert_equal elements.size, 1
    element = elements.first

    assert_equal 'alt', element['alt']
  end

  def test_should_show_bad_format
    html = ::Asciidoctor.convert(StringIO.new(DOC_BAD_FORMAT), backend: 'html5')

    page = Nokogiri::HTML(html)

    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1
  end

  def test_plantuml_multiple_listing
    html = ::Asciidoctor.convert(StringIO.new(DOC_MULTI), backend: 'html5')
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')
    assert elements.size >= 2

    elements = page.css('.plantuml-error')
    assert_equal elements.size, 0
  end

  def test_plantuml_multiple_literal
    html = ::Asciidoctor.convert(
      StringIO.new(DOC_MULTI_LITERAL), backend: 'html5'
    )
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')
    assert elements.size >= 2

    elements = page.css('.plantuml-error')
    assert_equal elements.size, 0
  end

  def test_plantuml_bad_server
    Asciidoctor::PlantUml.configure do |c|
      c.url = 'http://nonexistent.com/plantuml'
    end

    html = ::Asciidoctor.convert(StringIO.new(DOC_MULTI), backend: 'html5')
    page = Nokogiri::HTML(html)

    elements = page.css('img.plantuml')
    assert_equal 3, elements.size

    elements = page.css('.plantuml-error')
    assert_equal 0, elements.size
  end

  def test_plantuml_invalid_uri
    Asciidoctor::PlantUml.configure do |c|
      c.url = 'ftp://test.com'
    end

    html = ::Asciidoctor.convert(StringIO.new(DOC_BASIC), backend: 'html5')
    page = Nokogiri::HTML(html)
    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1
  end

  def test_plantuml_nil_uri
    Asciidoctor::PlantUml.configure do |c|
      c.url = nil
    end

    html = ::Asciidoctor.convert(StringIO.new(DOC_BASIC), backend: 'html5')
    page = Nokogiri::HTML(html)
    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1
  end

  def test_plantuml_empty_uri
    Asciidoctor::PlantUml.configure do |c|
      c.url = ''
    end

    html = ::Asciidoctor.convert(StringIO.new(DOC_BASIC), backend: 'html5')
    page = Nokogiri::HTML(html)
    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1
  end

  def test_disable_txt
    Asciidoctor::PlantUml.configure do |c|
      c.url = 'http://localhost:8080/plantuml'
      c.txt_enable = false
    end

    html = ::Asciidoctor.convert(StringIO.new(DOC_TXT), backend: 'html5')
    page = Nokogiri::HTML(html)
    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1
  end

  def test_svg
    Asciidoctor::PlantUml.configure do |c|
      c.url = 'http://localhost:8080/plantuml'
      c.svg_enable = true
    end

    html = ::Asciidoctor.convert(StringIO.new(DOC_SVG), backend: 'html5')
    page = Nokogiri::HTML(html)
    elements = page.css("object[type='image/svg+xml']")
    assert_equal elements.size, 1

    element = elements.first

    assert_equal SVGGENURL, element['data']
  end

  def test_disable_svg
    Asciidoctor::PlantUml.configure do |c|
      c.url = 'http://localhost:8080/plantuml'
      c.svg_enable = false
    end

    html = ::Asciidoctor.convert(StringIO.new(DOC_SVG), backend: 'html5')
    page = Nokogiri::HTML(html)
    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1
  end

  def test_disable_png
    Asciidoctor::PlantUml.configure do |c|
      c.url = 'http://localhost:8080/plantuml'
      c.png_enable = false
    end

    html = ::Asciidoctor.convert(StringIO.new(DOC_BASIC_LITERAL), backend: 'html5')
    page = Nokogiri::HTML(html)
    elements = page.css('pre.plantuml-error')
    assert_equal elements.size, 1
  end
end
