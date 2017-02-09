require 'uri'
require 'zlib'
require 'open-uri'
require 'net/http'
require "nokogiri"

module Asciidoctor
  module PlantUml

    class Configuration

      DEFAULT_URL = ENV["PLANTUML_URL"] || ""

      attr_accessor :url, :txt_enable, :svg_enable, :png_enable

      def initialize
        @url = DEFAULT_URL
        @txt_enable = true
        @svg_enable = true
        @png_enable = true
      end
    end

    class << self
      attr_writer :configuration
    end

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield(configuration)
    end

    class Processor

      FORMATS = ["png", "svg", "txt"]
      DEFAULT_FORMAT = FORMATS[0]

      class << self
        def valid_format?(format)
          FORMATS.include?(format)
        end

        def server_url
          PlantUml::configuration.url
        end

        def txt_enabled?
          PlantUml::configuration.txt_enable
        end

        def png_enabled?
          PlantUml::configuration.png_enable
        end

        def svg_enabled?
          PlantUml::configuration.svg_enable
        end

        def enabled?
          txt_enabled? || png_enabled? || svg_enabled?
        end

        def plantuml_content(code, attrs = {})

          format = attrs["format"] || DEFAULT_FORMAT

          if !enabled?
            return plantuml_disabled_content(code, attrs)
          end

          if !valid_uri?(server_url)
            return plantuml_server_unavailable_content(server_url, attrs)
          end

          case format
          when "png"
            plantuml_img_content(code, format, attrs)
          when "txt"
            if txt_enabled?
              plantuml_txt_content(code, format, attrs)
            else
              plantuml_invalid_content(format, attrs)
            end
          when "svg"
            plantuml_img_content(code, format, attrs)
          else
            plantuml_invalid_content(format, attrs)
          end
        end

        # Compression code used to generate PlantUML URLs. Taken directly from the
        # Transcoder class in the PlantUML java code.
        def gen_url(text, format)
          result = ""
          compressedData = Zlib::Deflate.deflate(text)
          compressedData.chars.each_slice(3) do |bytes|
            #print bytes[0], ' ' , bytes[1] , ' ' , bytes[2]
            b1 = bytes[0].nil? ? 0 : (bytes[0].ord & 0xFF)
            b2 = bytes[1].nil? ? 0 : (bytes[1].ord & 0xFF)
            b3 = bytes[2].nil? ? 0 : (bytes[2].ord & 0xFF)
            result += append3bytes(b1, b2, b3)
          end
          join_paths(server_url, "/#{format}/", result).to_s
        end

        private

        def plantuml_txt_content(code, format, attrs = {})
          begin
            url = gen_url(code, format)
            open(url) do |f|
              plantuml_ascii_content(f.read, format, attrs)
            end
          rescue
            plantuml_img_content(code, format, attrs)
          end
        end

        def plantuml_ascii_content(code, format, attrs = {})
          content = "<pre "
          content +="id=\"#{attrs['id']}\" " if attrs['id']
          content +="class=\"plantuml\">\n"
          content += code
          content +="</pre>"
        end

        def plantuml_img_content(code, format, attrs = {})
          content = "<img "
          content +="id=\"#{attrs['id']}\" " if attrs['id']
          content +="class=\"plantuml\" "
          content +="width=\"#{attrs['width']}\" " if attrs['width']
          content +="height=\"#{attrs['height']}\" " if attrs['height']
          content +="alt=\"#{attrs['alt']}\" " if attrs['alt']
          content +="src=\"#{gen_url(code, format)}\" />"
        end

        def plantuml_invalid_content(format, attrs = {})
          content = "<pre "
          content +="id=\"#{attrs['id']}\" " if attrs['id']
          content +="class=\"plantuml plantuml-error\"> "
          content += "PlantUML Error: Invalid format \"#{format}\""
          content +="</pre>"
        end

        def plantuml_server_unavailable_content(url, attrs = {})
          content = "<pre "
          content +="id=\"#{attrs['id']}\" " if attrs['id']
          content +="class=\"plantuml plantuml-error\"> "
          content += "PlantUML Error: cannot connect to PlantUML server at \"#{url}\""
          content +="</pre>"
        end

        def plantuml_disabled_content(code, attrs = {})
          content = "<pre "
          content +="id=\"#{attrs['id']}\" " if attrs['id']
          content +="class=\"plantuml plantuml-error\">\n"
          content += code
          content +="</pre>"
        end

        def encode6bit(b)
          if b < 10
            return ('0'.ord + b).chr
          end
          b = b - 10
          if b < 26
            return ('A'.ord + b).chr
          end
          b = b - 26
          if b < 26
            return ('a'.ord + b).chr
          end
          b = b - 26
          if b == 0
            return '-'
          end
          if b == 1
            return '_'
          end
          return '?'
        end

        def append3bytes(b1, b2, b3)
          c1 = b1 >> 2
          c2 = ((b1 & 0x3) << 4) | (b2 >> 4)
          c3 = ((b2 & 0xF) << 2) | (b3 >> 6)
          c4 = b3 & 0x3F
          return encode6bit(c1 & 0x3F).chr +
                 encode6bit(c2 & 0x3F).chr +
                 encode6bit(c3 & 0x3F).chr +
                 encode6bit(c4 & 0x3F).chr
        end

        # Make a call to the PlantUML server with the simplest diagram possible to
        # check if the server is available or not.
        def check_server(check_url)
          response = Net::HTTP.get_response(URI(check_url))
          return response.is_a?(Net::HTTPSuccess)
        rescue
          return false
        end

        def valid_uri?(uri)
          !(uri =~ /\A#{URI::regexp(['http', 'https'])}\z/).nil?
        end

        def join_paths(*paths, separator: '/')
          paths = paths.compact.reject(&:empty?)
          last = paths.length - 1
          paths.each_with_index.map { |path, index|
            expand_path(path, index, last, separator)
          }.join
        end

        def expand_path(path, current, last, separator)
          if path.start_with?(separator) && current != 0
            path = path[1..-1]
          end

          unless path.end_with?(separator) || current == last
            path = [path, separator]
          end

          path
        end
      end
    end

    # Postprocessor that replaces the listingblock class with the imageblock
    # class in all plantuml image blocks. This ensures plantuml images are
    # styled as images instead of listings.
    class PostProcessor < Asciidoctor::Extensions::Postprocessor
      def process document, output
        page = Nokogiri::HTML(output)

        page.css('img.plantuml').each do |img|
          img.parent.parent.parent['class'] = "imageblock"
        end

        page.to_s
      end
    end

    class BlockProcessor < Asciidoctor::Extensions::BlockProcessor

      use_dsl
      named :plantuml
      on_context :listing
      content_model :simple

      def process(parent, target, attrs)

        lines = target.lines

        if !(target.lines[0] =~ /@startuml/)
          lines = ["@startuml"] + target.lines
        end

        if !(target.lines[-1] =~ /@enduml/)
          lines += ["@enduml"]
        end

        content = Processor.plantuml_content(lines.join("\n"), attrs)

        return create_plantuml_block(parent, content, attrs)

      end

      private

      def create_plantuml_block(parent, content, attrs)
        Asciidoctor::Block.new parent, :listing,  {
          content_model: :raw,
          source: content,
          subs: :default,
          attributes: attrs}
      end

    end

  end
end
