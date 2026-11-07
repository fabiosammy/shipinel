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
      # What the block shows; "" for a rule.
      attr_reader :text #: String

      #: (Integer line_index, String text) -> void
      def initialize(line_index, text)
        @line_index = line_index
        @text = text
      end

      # Joins the next source line on, as Markdown does for a paragraph that
      # spans several lines.
      #: (String more) -> void
      def append(more)
        join_text(" ", more)
      end

      #: (String separator, String more) -> void
      def join_text(separator, more)
        @text = "#{@text}#{separator}#{more}"
        nil
      end

      #: (Integer other_line_index) -> bool
      def on_line?(other_line_index)
        @line_index == other_line_index
      end
    end

    # "## Segunda-feira": level 1 to 6.
    class Heading < Block
      attr_reader :level #: Integer

      #: (Integer line_index, Integer level, String text) -> void
      def initialize(line_index, level, text)
        super(line_index, text)
        @level = level
      end
    end

    # A bullet or a task. Depth 0 is the top level; each deeper indentation
    # under an earlier item adds one.
    class ListItem < Block
      attr_reader :depth #: Integer

      #: (Integer line_index, Integer depth, String text) -> void
      def initialize(line_index, depth, text)
        super(line_index, text)
        @depth = depth
      end
    end

    # "- comprar pão"
    # "- comprar pão" or "2. Revisar": the marker shown before the text is
    # "•" for an unordered item and the item's own number ("2.") otherwise.
    class Bullet < ListItem
      attr_reader :marker #: String

      #: (Integer line_index, Integer depth, String text, String marker) -> void
      def initialize(line_index, depth, text, marker)
        super(line_index, depth, text)
        @marker = marker
      end
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
    end

    # A horizontal rule: "---", "* * *" or "___".
    class Rule < Block
    end

    # A table: consecutive "| a | b |" lines. Its cells are its text, joined
    # by SEPARATOR, row after row: Spinel does not carry an array attribute
    # through `is_a?` (docs/spinel-notes.md), and has no typed array of
    # arrays. Every row has `columns` cells, padded or cut to the first
    # row's count. The row of dashes under the header is not kept: it marks
    # the rows above it as header rows.
    class Table < Block
      # The ASCII unit separator: never typed in a Markdown file.
      SEPARATOR = "\u001F"
      # Example match: "| 1. Drata | 12 tests FAILED |" (inner
      # " 1. Drata | 12 tests FAILED ")
      ROW = /\A\s*\|(?<inner>.*)\|\s*\z/

      attr_reader :columns #: Integer
      attr_reader :header_rows #: Integer

      # The cells of a table row line, or [] for any other line.
      #: (String text) -> Array[String]
      def self.cells_in(text)
        match = ROW.match(text)
        match ? match[:inner].to_s.split("|").map(&:strip) : []
      end

      # The row under the header: every cell dashes, with colons for
      # alignment (":---:"). Not all?/grep_v: Spinel's Enumerable versions
      # widen (docs/spinel-notes.md).
      #: (Array[String] cells) -> bool
      def self.delimiter?(cells)
        cells.reject { |cell| cell.include?("-") && cell.delete(":-").empty? }.empty?
      end

      #: (Integer line_index, Array[String] cells) -> void
      def initialize(line_index, cells)
        super(line_index, cells.join(SEPARATOR))
        @columns = cells.size
        @header_rows = 0
      end

      #: (Array[String] cells) -> void
      def add_row(cells)
        return mark_header if Table.delimiter?(cells)

        row = Array.new(@columns) { |column| cells[column].to_s }
        join_text(SEPARATOR, row.join(SEPARATOR))
      end

      #: () -> Integer
      def rows
        text.split(SEPARATOR, -1).size / @columns
      end

      private

      #: () -> void
      def mark_header
        @header_rows = rows if @header_rows.zero?
        nil
      end
    end

    # One line inside a fenced code block, shown as it is.
    class CodeLine < Block
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

      # The task that starts on this source line, if there is one. Typed
      # Block? because Spinel does not narrow a return through `is_a?`
      # (docs/spinel-notes.md); callers check `is_a?(Task)` again.
      #: (Integer line_index) -> Block?
      def task_on_line(line_index)
        position = 0
        while position < @blocks.size
          block = @blocks[position]
          return block if block.is_a?(Task) && block.on_line?(line_index)

          position += 1
        end
        nil
      end
    end
  end
end
