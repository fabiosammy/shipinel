# frozen_string_literal: true

# Toggles one task checkbox in the file. It re-reads the file first and
# changes the line only if the parser still sees that task there, in the
# state the user clicked; otherwise an edit made since the last reload would
# be overwritten. Only the "[ ]"/"[x]" characters change.

require_relative "document_file"
require_relative "markdown/parser"

module Shipinel
  # A click on a task's checkbox: the source line, and the state the user
  # saw when clicking.
  class TaskClick
    # The first bracket pair on a task line is its checkbox: the indentation
    # and bullet before it cannot contain brackets.
    # Example match: "[X]" in "  - [X] Ligar para a Ana"
    CHECKBOX = /\[[ xX]\]/
    CHECKED = "[x]"
    UNCHECKED = "[ ]"

    attr_reader :line_index #: Integer

    # @rbs @checked: bool

    #: (Integer line_index, bool checked) -> void
    def initialize(line_index, checked)
      @line_index = line_index
      @checked = checked
    end

    # The state the user saw, which the click flips.
    #: () -> bool
    def checked?
      @checked
    end

    # The content with this checkbox flipped, or nil when the content no
    # longer has this task in the state the user saw.
    #: (String content) -> String?
    def apply_to(content)
      still_valid_in?(content) ? flipped(content) : nil
    end

    private

    # Parsing again (not just matching the line) also catches a task that a
    # newly added fence above has turned into code.
    #: (String content) -> bool
    def still_valid_in?(content)
      task = Markdown::Parser.parse(content).task_on_line(@line_index)
      task.is_a?(Markdown::Task) && task.checked? == @checked
    end

    # `lines` keeps each line ending, so CRLF files and a missing final
    # newline come back exactly as they were.
    #: (String content) -> String
    def flipped(content)
      lines = content.lines
      lines[@line_index] = lines[@line_index].to_s.sub(CHECKBOX, @checked ? UNCHECKED : CHECKED)
      lines.join
    end
  end

  # What a toggle did: :toggled, :line_changed (the file no longer has that
  # task in that state; the next reload shows what it has) or :failed, with
  # `problem` saying why.
  class ToggleResult
    attr_reader :status #: Symbol
    attr_reader :problem #: String

    #: (Symbol status, String problem) -> void
    def initialize(status, problem)
      @status = status
      @problem = problem
    end
  end

  # See the file comment.
  class TaskToggler
    # @rbs @file: DocumentFile

    #: (DocumentFile file) -> void
    def initialize(file)
      @file = file
    end

    #: (TaskClick click) -> ToggleResult
    def toggle(click)
      snapshot = @file.read
      problem = snapshot.problem
      return ToggleResult.new(:failed, problem) unless problem.empty?

      save(click.apply_to(snapshot.content))
    end

    private

    #: (String? toggled) -> ToggleResult
    def save(toggled)
      return ToggleResult.new(:line_changed, "") unless toggled

      problem = @file.write(toggled)
      ToggleResult.new(problem.empty? ? :toggled : :failed, problem)
    end
  end
end
