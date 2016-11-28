require 'uri'
require 'zlib'
require 'open-uri'
require 'net/http'

module Asciidoctor
  module PlantUml

    class Configuration

      DEFAULT_URL = ENV["PLANTUML_URL"] || "http://localhost:8080/plantuml"

      attr_accessor :url, :test

      def initialize
        @url = DEFAULT_URL
        @test = false
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

    module Processor

      FORMATS = ["png", "svg", "txt"]
      DEFAULT_FORMAT = FORMATS[0]

      def valid_format?(format)
        FORMATS.include?(format)
      end

      def server_url
        PlantUml::configuration.url
      end

      def plantuml_content(code, format, attrs = {})
        content = "<div class=\"imageblock\">"
        content += "<div class=\"content\">"
        content += "<img "
        content +="id=\"#{attrs['id']}\" " if attrs['id']
        content +="class=\"plantuml\" "
        content +="width=\"#{attrs['width']}\" " if attrs['width']
        content +="height=\"#{attrs['height']}\" " if attrs['height']
        content +="alt=\"#{attrs['alt']}\" " if attrs['alt']
        content +="src=\"#{gen_url(code, format)}\" />"
        content += "</div>"
        content += "</div>"
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


      def create_plantuml_block(parent, content)
        Asciidoctor::Block.new parent, :pass, :content_model => :raw,
          :source => content, :subs => :default
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

    class BlockProcessor < Asciidoctor::Extensions::BlockProcessor
      include Processor

      def process(parent, target, attrs)

        testing = attrs["test"] == "true"

        check_url = join_paths(server_url, "/png/SyfFKj2rKt3CoKnELR1Io4ZDoSa70000")

        if ! check_server(check_url) && ! testing
          content = "<div class='plantuml'>PlantUML server [#{check_url}] is unreachable</div>"
          return create_plantuml_block(parent, content)
        end

        format = attrs["format"] || DEFAULT_FORMAT

        if ! valid_format?(format)
          content = "<div class='plantuml'>Invalid format #{format}</div>"
          return create_plantuml_block(parent, content)
        end

        lines = target.lines

        if !(target.lines[0] =~ /@startuml/)
          lines = ["@startuml"] + target.lines
        end

        if !(target.lines[-1] =~ /@enduml/)
          lines += ["@enduml"]
        end

        content = plantuml_content(lines.join("\n"), format, attrs)
        return create_plantuml_block(parent, content)

      end
    end

  end
end
