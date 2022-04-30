# frozen_string_literal: true

require 'uri'
require 'open-uri'
require 'zlib'
require 'net/http'

module Asciidoctor
  # PlantUML Module
  module PlantUml
    # PlantUML Configuration
    class Configuration
      DEFAULT_URL = ENV.fetch('PLANTUML_URL', '')
      DEFAULT_ENCODING = ENV.fetch('PLANTUML_ENCODING', 'legacy')

      attr_accessor :url, :txt_enable, :svg_enable, :png_enable, :encoding

      def initialize
        @url = DEFAULT_URL
        @txt_enable = true
        @svg_enable = true
        @png_enable = true
        @encoding = DEFAULT_ENCODING
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

    # PlantUML Processor
    class Processor
      FORMATS = %w[png svg txt].freeze
      DEFAULT_FORMAT = FORMATS[0]

      ENCODINGS = %w[legacy deflate].freeze
      DEFAULT_ENCODING = ENCODINGS[0]

      ENCODINGS_MAGIC_STRINGS_MAP = Hash.new('')
      ENCODINGS_MAGIC_STRINGS_MAP['deflate'] = '~1'

      URI_SCHEMES_REGEXP = ::URI::DEFAULT_PARSER.make_regexp(%w[http https])

      class << self
        def valid_format?(format)
          FORMATS.include?(format)
        end

        def valid_encoding?(encoding)
          ENCODINGS.include?(encoding)
        end

        def server_url
          PlantUml.configuration.url
        end

        def txt_enabled?
          PlantUml.configuration.txt_enable
        end

        def png_enabled?
          PlantUml.configuration.png_enable
        end

        def svg_enabled?
          PlantUml.configuration.svg_enable
        end

        def enabled?
          txt_enabled? || png_enabled? || svg_enabled?
        end

        def plantuml_content_format(parent, code, format, attrs = {})
          content = code.read

          # honor subs attributes
          # e.g. replace asciidoc variables
          subs = attrs['subs']
          content = parent.apply_subs(content, parent.resolve_subs(subs)) if subs

          # add @start... and @end... if missing
          content = "@startuml\n#{content}\n@enduml" unless content =~ /^@start.*@end[a-z]*$/m

          # insert global plantuml config after first line
          config_path = parent.attr('plantuml-include', '', true)
          begin
            content = insert_config_to_content(parent, config_path, content, attrs) unless config_path.empty?
          rescue StandardError => e
            return plantuml_invalid_file(config_path, e.message, attrs)
          end

          if %w[png svg txt].include?(format) && method("#{format}_enabled?").call
            method("plantuml_#{format}_content").call(content, format, attrs)
          else
            plantuml_invalid_content(format, attrs)
          end
        end

        def plantuml_content(parent, code, attrs = {})
          format = attrs['format'] || DEFAULT_FORMAT

          return plantuml_disabled_content(code, attrs) unless enabled?

          return plantuml_server_unavailable_content(server_url, attrs) unless valid_uri?(server_url)

          plantuml_content_format(parent, code, format, attrs)
        end

        def plantuml_content_from_file(parent, source_file, attrs = {})
          File.open(source_file) do |f|
            return plantuml_content(parent, f, attrs)
          end
        rescue StandardError => e
          plantuml_invalid_file(source_file, e.message, attrs)
        end

        # Compression code used to generate PlantUML URLs. Taken directly from
        # the transcoder class in the PlantUML java code.
        def gen_url(text, format)
          result = ''
          result += encoding_magic_prefix
          compressed_data = Zlib::Deflate.deflate(text)
          compressed_data.chars.each_slice(3) do |bytes|
            # print bytes[0], ' ' , bytes[1] , ' ' , bytes[2]
            b1 = bytes[0].nil? ? 0 : (bytes[0].ord & 0xFF)
            b2 = bytes[1].nil? ? 0 : (bytes[1].ord & 0xFF)
            b3 = bytes[2].nil? ? 0 : (bytes[2].ord & 0xFF)
            result += append3bytes(b1, b2, b3)
          end
          join_paths(server_url, "#{format}/", result).to_s
        end

        def create_plantuml_block(parent, content, attrs)
          Asciidoctor::Block.new parent, :pass, {
            content_model: :raw,
            source: content,
            subs: :default
          }.merge(attrs)
        end

        private

        def insert_config_to_content(parent, config_path, content, attrs)
          File.open(config_path) do |file|
            config = file.read
            subs = attrs['subs']
            config = parent.apply_subs(config, parent.resolve_subs(subs)) if subs
            content.insert(content.index("\n"), "\n#{config}") unless config.empty?
            return content
          end
        end

        def plantuml_txt_content(code, format, attrs = {})
          url = gen_url(code, format)
          URI(url).open do |f|
            plantuml_ascii_content(f.read, attrs)
          end
        rescue OpenURI::HTTPError, Errno::ECONNREFUSED, SocketError
          plantuml_png_content(code, format, attrs)
        end

        def plantuml_ascii_content(code, attrs = {})
          content = '<div class="listingblock">'
          content += '<div class="content">'
          content += '<pre '
          content += "id=\"#{attrs['id']}\" " if attrs['id']
          content += 'class="plantuml">\n'
          content += code
          content += '</pre>'
          content += '</div>'
          content + '</div>'
        end

        def plantuml_png_content(code, format, attrs = {})
          content = '<div class="imageblock">'
          content += '<div class="content">'
          content += '<img '
          content += "id=\"#{attrs['id']}\" " if attrs['id']
          content += 'class="plantuml" '
          content += "width=\"#{attrs['width']}\" " if attrs['width']
          content += "height=\"#{attrs['height']}\" " if attrs['height']
          content += "alt=\"#{attrs['alt']}\" " if attrs['alt']
          content += "src=\"#{gen_url(code, format)}\" />"
          content += '</div>'
          content + '</div>'
        end

        def plantuml_svg_content(code, format, attrs = {})
          content = '<div class="imageblock">'
          content += '<div class="content">'
          content += '<object type="image/svg+xml" '
          content += "data=\"#{gen_url(code, format)}\" "
          content += "id=\"#{attrs['id']}\" " if attrs['id']
          content += "width=\"#{attrs['width']}\" " if attrs['width']
          content += "height=\"#{attrs['height']}\" " if attrs['height']
          content += '>'
          attrs['id'] = 'fallback_' + attrs['id'] if attrs['id']
          content += plantuml_png_content(code, format, attrs)
          content += '</object>'
          content += '</div>'
          content + '</div>'
        end

        def plantuml_invalid_content(format, attrs = {})
          error = "PlantUML Error: Invalid format \"#{format}\""
          _plantuml_error_content(error, attrs)
        end

        def plantuml_server_unavailable_content(url, attrs = {})
          error = "Error: cannot connect to PlantUML server at \"#{url}\""
          _plantuml_error_content(error, attrs)
        end

        def plantuml_disabled_content(code, attrs = {})
          _plantuml_error_content(code, attrs)
        end

        def plantuml_invalid_file(file, error, attrs = {})
          error = "PlantUML Error: Could not parse \"#{file}\": #{error}"
          _plantuml_error_content(error, attrs)
        end

        def _plantuml_error_content(error, attrs = {})
          content = '<div class="listingblock">'
          content += '<div class="content">'
          content += '<pre '
          content += "id=\"#{attrs['id']}\" " if attrs['id']
          content += 'class="plantuml plantuml-error">\n'
          content += error
          content += '</pre>'
          content += '</div>'
          content + '</div>'
        end

        def encode6bit(bit)
          return ('0'.ord + bit).chr if bit < 10

          bit -= 10
          return ('A'.ord + bit).chr if bit < 26

          bit -= 26
          return ('a'.ord + bit).chr if bit < 26

          bit -= 26
          return '-' if bit.zero?

          return '_' if bit == 1

          '?'
        end

        def append3bytes(bit1, bit2, bit3)
          c1 = bit1 >> 2
          c2 = ((bit1 & 0x3) << 4) | (bit2 >> 4)
          c3 = ((bit2 & 0xF) << 2) | (bit3 >> 6)
          c4 = bit3 & 0x3F
          encode6bit(c1 & 0x3F).chr +
            encode6bit(c2 & 0x3F).chr +
            encode6bit(c3 & 0x3F).chr +
            encode6bit(c4 & 0x3F).chr
        end

        def encoding_magic_prefix
          ENCODINGS_MAGIC_STRINGS_MAP[PlantUml.configuration.encoding]
        end

        # Make a call to the PlantUML server with the simplest diagram possible
        # to check if the server is available or not.
        def check_server(check_url)
          response = Net::HTTP.get_response(URI(check_url))
          response.is_a?(Net::HTTPSuccess)
        rescue OpenURI::HTTPError, Errno::ECONNREFUSED, SocketError
          false
        end

        def valid_uri?(uri)
          !(uri =~ /\A#{URI_SCHEMES_REGEXP}\z/).nil?
        end

        def join_paths(*paths, separator: '/')
          paths = paths.compact.reject(&:empty?)
          last = paths.length - 1
          paths.each_with_index.map do |path, index|
            expand_path(path, index, last, separator)
          end.join
        end

        def expand_path(path, current, last, separator)
          path = path[1..] if path.start_with?(separator) && current.zero?

          path = [path, separator] unless path.end_with?(separator) || current == last

          path
        end
      end
    end

    # PlantUML BlockProcessor
    class BlockProcessor < Asciidoctor::Extensions::BlockProcessor
      use_dsl
      named :plantuml
      on_context :listing, :literal
      content_model :simple

      def process(parent, target, attrs)
        content = Processor.plantuml_content(parent, target, attrs)
        Processor.create_plantuml_block(parent, content, attrs)
      end
    end

    # PlantUML BlockMacroProcessor
    class BlockMacroProcessor < Asciidoctor::Extensions::BlockMacroProcessor
      use_dsl
      named :plantuml

      def process(parent, target, attrs)
        base_dir = parent.document.base_dir
        source_file = parent.document.path_resolver.system_path(target, base_dir, base_dir)
        content = Processor.plantuml_content_from_file(parent, source_file, attrs)
        Processor.create_plantuml_block(parent, content, attrs)
      end
    end
  end
end
