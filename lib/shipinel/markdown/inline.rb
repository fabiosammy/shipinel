# frozen_string_literal: true

# Splits one line of block text into styled spans: **bold**, `code`, links
# and plain text. A marker without its closing partner stays as literal
# text.

require_relative "links"

module Shipinel
  module Markdown
    # A run of text in one style: :plain, :bold, :code or :link. A link
    # also has its url; every other span's url is "".
    class Span
      attr_reader :text #: String
      attr_reader :style #: Symbol
      attr_reader :url #: String

      #: (String text, Symbol style, String url) -> void
      def initialize(text, style, url)
        @text = text
        @style = style
        @url = url
      end
    end

    # The spans of one line, in order. Kept in an ivar and read by index so
    # Spinel compiles it to a typed array (docs/spinel-notes.md).
    class SpanList
      # @rbs @spans: Array[Span]

      #: () -> void
      def initialize
        @spans = []
      end

      #: (Span span) -> void
      def add(span)
        @spans << span
        nil
      end

      #: () -> Integer
      def size
        @spans.size
      end

      #: (Integer position) -> Span
      def at(position)
        @spans[position]
      end
    end

    # See the file comment. Code is matched first, so "`**`" and a URL in
    # backticks stay code. Bold and link text are not scanned again: no
    # nesting, simple styling is enough.
    class Inline
      CODE = "`"
      BOLD = "**"
      NOT_FOUND = -1

      # @rbs @text: String
      # @rbs @spans: SpanList
      # @rbs @position: Integer
      # @rbs @plain: String

      #: (String text) -> SpanList
      def self.parse(text)
        new(text).spans
      end

      #: (String text) -> void
      def initialize(text)
        @text = text
        @spans = SpanList.new
        @position = 0
        @plain = ""
      end

      #: () -> SpanList
      def spans
        step while @position < @text.size
        flush_plain
        @spans
      end

      private

      #: () -> void
      def step
        if marker_at?(CODE, @position) then take(CODE, :code)
        elsif marker_at?(BOLD, @position) then take(BOLD, :bold)
        else take_link_or_char
        end
        nil
      end

      #: () -> void
      def take_link_or_char
        link = link_here
        link ? take_link(link) : keep_plain(@text[@position, 1].to_s)
      end

      # Links are only looked for where one could start.
      #: () -> LinkMatch?
      def link_here
        return nil unless Links::STARTS.include?(@text[@position, 1].to_s)

        Links.at(@text[@position, @text.size - @position].to_s)
      end

      #: (LinkMatch link) -> void
      def take_link(link)
        flush_plain
        @spans.add(Span.new(link.text, :link, link.url))
        @position += link.length
        nil
      end

      # A marker with no closing partner, or with nothing between the two,
      # is plain text.
      #: (String marker, Symbol style) -> void
      def take(marker, style)
        content_start = @position + marker.size
        close = closing_at(marker, content_start)
        return keep_plain(marker) unless close > content_start

        add_span(style, content_start, close)
        skip(marker)
      end

      # String#index would pull Spinel's widening Enumerator builtins in
      # (docs/spinel-notes.md), so the scan is written out.
      #: (String marker, Integer from) -> Integer
      def closing_at(marker, from)
        position = from
        while position < @text.size
          return position if marker_at?(marker, position)

          position += 1
        end
        NOT_FOUND
      end

      #: (String marker, Integer position) -> bool
      def marker_at?(marker, position)
        @text[position, marker.size] == marker
      end

      #: (String text) -> void
      def keep_plain(text)
        @plain = "#{@plain}#{text}"
        skip(text)
      end

      #: (String text) -> void
      def skip(text)
        @position += text.size
        nil
      end

      # Leaves the scan on the closing marker.
      #: (Symbol style, Integer content_start, Integer close) -> void
      def add_span(style, content_start, close)
        flush_plain
        @spans.add(Span.new(@text[content_start, close - content_start].to_s, style, ""))
        @position = close
        nil
      end

      #: () -> void
      def flush_plain
        return if @plain.empty?

        @spans.add(Span.new(@plain, :plain, ""))
        @plain = ""
      end
    end
  end
end
