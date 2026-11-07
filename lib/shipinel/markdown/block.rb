# frozen_string_literal: true

# The value objects the parser produces, one per rendered block, and the list
# that holds them. Every block keeps the index of its source line, so a click
# maps back to a line of the file, never to "the n-th checkbox".

module Shipinel
  module Markdown
    # The base of every block. Subclasses only add data: Spinel compiles a
    # list of blocks to one typed array when no method is overridden
    # (docs/spinel-notes.md), so callers tell kinds apart with `is_a?`.
    class Block
      attr_reader :line_index #: Integer

      #: (Integer line_index) -> void
      def initialize(line_index)
        @line_index = line_index
      end
    end

    # "## Segunda-feira": level 1 to 6.
    class Heading < Block
      attr_reader :level #: Integer
      attr_reader :text #: String

      #: (Integer line_index, Integer level, String text) -> void
      def initialize(line_index, level, text)
        super(line_index)
        @level = level
        @text = text
      end
    end

    # A bullet or a task. Depth 0 is the top level; each deeper indentation
    # under an earlier item adds one.
    class ListItem < Block
      attr_reader :depth #: Integer
      attr_reader :text #: String

      #: (Integer line_index, Integer depth, String text) -> void
      def initialize(line_index, depth, text)
        super(line_index)
        @depth = depth
        @text = text
      end
    end

    # "- comprar pão"
    class Bullet < ListItem
    end

    # "- [x] Ligar para a Ana"
    class Task < ListItem
      # @rbs @checked: bool

      #: (Integer line_index, Integer depth, String text, bool checked) -> void
      def initialize(line_index, depth, text, checked)
        super(line_index, depth, text)
        @checked = checked
      end

      #: () -> bool
      def checked?
        @checked
      end
    end

    # Consecutive text lines, joined with spaces as Markdown does. The line
    # index is the paragraph's first line.
    class Paragraph < Block
      attr_reader :text #: String

      #: (Integer line_index, String text) -> void
      def initialize(line_index, text)
        super(line_index)
        @text = text
      end

      #: (String more) -> void
      def append(more)
        @text = "#{@text} #{more}"
      end
    end

    # A horizontal rule: "---", "* * *" or "___".
    class Rule < Block
    end

    # One line inside a fenced code block, shown as it is.
    class CodeLine < Block
      attr_reader :text #: String

      #: (Integer line_index, String text) -> void
      def initialize(line_index, text)
        super(line_index)
        @text = text
      end
    end

    # The blocks of one document, in source order. A plain Array of objects
    # would compile to an untyped array under Spinel; kept in this ivar and
    # read by index, it stays typed (docs/spinel-notes.md).
    class BlockList
      # @rbs @blocks: Array[Block]

      #: () -> void
      def initialize
        @blocks = []
      end

      #: (Block block) -> void
      def add(block)
        @blocks << block
        nil
      end

      #: () -> Integer
      def size
        @blocks.size
      end

      #: (Integer position) -> Block
      def at(position)
        @blocks[position]
      end
    end
  end
end
