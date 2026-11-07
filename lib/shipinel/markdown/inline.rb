# frozen_string_literal: true

# Splits one line of block text into styled spans: **bold**, `code` and plain
# text. A marker without its closing partner stays as literal text.

module Shipinel
  module Markdown
    # A run of text in one style: :plain, :bold or :code.
    class Span
      attr_reader :text #: String
      attr_reader :style #: Symbol

      #: (String text, Symbol style) -> void
      def initialize(text, style)
        @text = text
        @style = style
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

    # See the file comment. Code is matched before bold, so "`**`" is code.
    # Bold text is not scanned again: no nesting, simple styling is enough.
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
        else keep_plain(@text[@position, 1].to_s)
        end
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
        @spans.add(Span.new(@text[content_start, close - content_start].to_s, style))
        @position = close
        nil
      end

      #: () -> void
      def flush_plain
        return if @plain.empty?

        @spans.add(Span.new(@plain, :plain))
        @plain = ""
      end
    end
  end
end
