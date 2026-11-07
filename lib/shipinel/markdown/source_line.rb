# frozen_string_literal: true

# One line of the Markdown file, without its line ending, and its index
# (from 0). Blocks carry the index so a click maps back to this line.

module Shipinel
  module Markdown
    # See the file comment.
    class SourceLine
      attr_reader :text #: String
      attr_reader :line_index #: Integer

      #: (String text, Integer line_index) -> void
      def initialize(text, line_index)
        @text = text
        @line_index = line_index
      end

      #: () -> bool
      def blank?
        @text.strip.empty?
      end
    end
  end
end
