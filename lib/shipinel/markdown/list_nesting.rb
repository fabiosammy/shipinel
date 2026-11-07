# frozen_string_literal: true

# Turns list item indentation into nesting depth. Depth comes from comparing
# with the items above, not from a fixed width, so lists indented by 2 or by
# 4 spaces nest the same way.

module Shipinel
  module Markdown
    # See the file comment.
    class ListNesting
      # A tab indents as far as this many spaces.
      TAB_WIDTH = 4

      # @rbs @indents: Array[Integer]

      #: () -> void
      def initialize
        @indents = []
      end

      # Indents of the items this one may be nested under are kept on a
      # stack; items indented as far or further are siblings or done.
      #: (String indent) -> Integer
      def depth_for(indent)
        width = indent.gsub("\t", " " * TAB_WIDTH).size
        @indents.pop while !@indents.empty? && @indents.last >= width
        @indents << width
        @indents.size - 1
      end

      # Anything that is not a list item ends the list.
      #: () -> void
      def reset
        @indents.clear
        nil
      end
    end
  end
end
