# frozen_string_literal: true

# Splits one line of block text into styled spans: **bold**, *italic*,
# ~~strike~~, `code`, links and plain text. A marker without its closing
# partner stays as literal text.

require_relative "emphasis"
require_relative "links"
require_relative "span"

module Shipinel
  module Markdown
    # See the file comment. Code is matched first, so "`**`" and a URL in
    # backticks stay code. Bold and link text are not scanned again: no
    # nesting, simple styling is enough.
    class Inline
      CODE = "`"
      BOLD = "**"
      STRIKE = "~~"
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
        elsif marker_at?(STRIKE, @position) then take(STRIKE, :strike)
        else take_italic_link_or_char
        end
        nil
      end

      #: () -> void
      def take_italic_link_or_char
        close = Emphasis.close_of(@text, @position)
        return take_link_or_char if close == NOT_FOUND

        add_span(:italic, @position + 1, close)
        @position += 1
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
