# frozen_string_literal: true

# The document as the window shows it: the last read of the file, its
# blocks, and what to tell the user about it. Toggling goes through
# TaskToggler and then reloads, so the page always shows what is on disk.

require_relative "document_file"
require_relative "markdown/parser"
require_relative "task_toggler"

module Shipinel
  # See the file comment.
  class DocumentView
    attr_reader :blocks #: Markdown::BlockList

    # @rbs @file: DocumentFile
    # @rbs @snapshot: Snapshot
    # @rbs @toggle_problem: String

    #: (DocumentFile file) -> void
    def initialize(file)
      @file = file
      @snapshot = file.read
      @blocks = parse
      @toggle_problem = ""
    end

    # Re-reads the file; parses again only when something changed. A file
    # that went missing shows its notice and an empty page, and comes back
    # by itself when the file reappears.
    #: () -> void
    def reload
      snapshot = @file.read
      return if snapshot.same_as?(@snapshot)

      @snapshot = snapshot
      @blocks = parse
      @toggle_problem = ""
    end

    #: (TaskClick click) -> ToggleResult
    def toggle(click)
      result = TaskToggler.new(@file).toggle(click)
      @toggle_problem = result.problem
      reload
      result
    end

    # Shown above the document: why the file cannot be read, and why the
    # last click could not be saved.
    #: () -> Array[String]
    def notices
      [@snapshot.problem, @toggle_problem].reject(&:empty?)
    end

    private

    #: () -> Markdown::BlockList
    def parse
      Markdown::Parser.parse(@snapshot.content)
    end
  end
end
