# frozen_string_literal: true

# Finds where an italic run (*text* or _text_) closes, by Markdown's rules:
# the markers hug the text ("2 * 3 * 4" is not italic), and "_" only counts
# at word edges, so snake_case and workspace_id stay as they are.

module Shipinel
  module Markdown
    # See the file comment. One Emphasis looks for one marker in one text.
    class Emphasis
      MARKERS = "*_"
      # Example match: "a", "ç" or "7": a character "_" must not touch.
      WORD_CHAR = /\A[[:alnum:]]\z/
      NOT_FOUND = -1

      # @rbs @text: String
      # @rbs @marker: String
      # @rbs @word_edges: bool

      # Where the italic run that opens at `position` closes, or NOT_FOUND.
      #: (String text, Integer position) -> Integer
      def self.close_of(text, position)
        marker = text[position, 1].to_s
        return NOT_FOUND unless !marker.empty? && MARKERS.include?(marker)

        Emphasis.new(text, marker).close_after(position)
      end

      #: (String text, String marker) -> void
      def initialize(text, marker)
        @text = text
        @marker = marker
        @word_edges = marker == "_"
      end

      #: (Integer position) -> Integer
      def close_after(position)
        return NOT_FOUND unless opens_at?(position)

        candidate = position + 2
        while candidate < @text.size
          return candidate if closes_at?(candidate)

          candidate += 1
        end
        NOT_FOUND
      end

      private

      # A marker opens when text follows it at once (not a space, not a
      # second marker: "**" is bold), and "_" when no letter is before it.
      #: (Integer position) -> bool
      def opens_at?(position)
        following = char_at(position + 1)
        return false if following.strip.empty? || following == @marker

        !(@word_edges && word_at?(position - 1))
      end

      # A marker closes right after text (not a space), and "_" when no
      # letter follows it.
      #: (Integer position) -> bool
      def closes_at?(position)
        return false unless char_at(position) == @marker && !char_at(position - 1).strip.empty?

        !(@word_edges && word_at?(position + 1))
      end

      #: (Integer position) -> bool
      def word_at?(position)
        WORD_CHAR.match?(char_at(position))
      end

      # Before the start there is nothing, not text[-1] (the last character).
      #: (Integer position) -> String
      def char_at(position)
        return "" if position.negative?

        @text[position, 1].to_s
      end
    end
  end
end
