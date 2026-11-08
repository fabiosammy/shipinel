# frozen_string_literal: true

# The styled runs of text Inline splits a line into, and the list that
# holds them.

module Shipinel
  module Markdown
    # A run of text in one style: :plain, :bold, :italic, :strike, :code or
    # :link. A link also has its url; every other span's url is "".
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

      # The text without its markup: "**Goal 1** — [Drata](x)" gives
      # "Goal 1 — Drata".
      #: () -> String
      def plain
        text = ""
        @spans.each { |span| text = "#{text}#{span.text}" }
        text
      end

      #: (Integer position) -> Span
      def at(position)
        @spans[position]
      end
    end
  end
end
