# frozen_string_literal: true

# The document as the window shows it: the last read of the file and its
# blocks. A file that cannot be read shows the reason instead. Toggling
# goes through TaskToggler and then reloads, so the page always shows what
# is on disk.

require_relative "document_file"
require_relative "markdown/parser"
require_relative "task_toggler"

module Shipinel
  # See the file comment.
  class DocumentView
    attr_reader :blocks #: Markdown::BlockList

    # @rbs @file: DocumentFile
    # @rbs @snapshot: Snapshot

    #: (DocumentFile file) -> void
    def initialize(file)
      @file = file
      @snapshot = file.read
      @blocks = Markdown::Parser.parse(shown_text)
    end

    # Re-reads the file; parses again only when something changed.
    #: () -> void
    def reload
      snapshot = @file.read
      return if snapshot.same_as?(@snapshot)

      @snapshot = snapshot
      @blocks = Markdown::Parser.parse(shown_text)
    end

    #: (TaskClick click) -> ToggleResult
    def toggle(click)
      result = TaskToggler.new(@file).toggle(click)
      reload
      result
    end

    private

    #: () -> String
    def shown_text
      @snapshot.readable? ? @snapshot.content : @snapshot.problem
    end
  end
end
