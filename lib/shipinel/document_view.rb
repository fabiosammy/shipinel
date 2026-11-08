# frozen_string_literal: true

# The document as the window shows it: the last read of the file, its
# blocks, and what to tell the user about it. Toggling goes through
# TaskToggler and then reloads, so the page always shows what is on disk;
# links open next to the file. The last tick can be undone once.

require_relative "document_file"
require_relative "link_opener"
require_relative "markdown/parser"
require_relative "task_toggler"

module Shipinel
  # What the last click left: why it could not be saved or opened ("" when
  # it worked), and the click that would undo it (TaskClick.none when there
  # is nothing to undo: a link, a failed save, or an undo already done).
  class LastAction
    attr_reader :problem #: String
    attr_reader :undo #: TaskClick

    #: (String problem, TaskClick undo) -> void
    def initialize(problem, undo)
      @problem = problem
      @undo = undo
    end

    #: () -> LastAction
    def self.none
      LastAction.new("", TaskClick.none)
    end

    # After a click on a checkbox: undoable when it was saved.
    #: (TaskClick click, ToggleResult result) -> LastAction
    def self.after(click, result)
      LastAction.new(result.problem, result.toggled? ? click.put_back : TaskClick.none)
    end
  end

  # See the file comment.
  class DocumentView
    attr_reader :blocks #: Markdown::BlockList

    # @rbs @file: DocumentFile
    # @rbs @snapshot: Snapshot
    # @rbs @last: LastAction

    #: (DocumentFile file) -> void
    def initialize(file)
      @file = file
      @snapshot = file.read
      @blocks = parse
      @last = LastAction.none
    end

    # Why the last click could not be saved or opened ("" when it worked).
    #: () -> String
    def action_problem
      @last.problem
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
      @last = LastAction.new("", @last.undo)
    end

    # A click on a checkbox; `u` puts it back (undo).
    #: (TaskClick click) -> ToggleResult
    def toggle(click)
      result = TaskToggler.new(@file).toggle(click)
      @last = LastAction.after(click, result)
      reload
      result
    end

    # Flips the last saved click back, once: a second `u` does nothing. The
    # same safe toggle: when the line changed since, nothing is written.
    #: () -> ToggleResult
    def undo
      click = @last.undo
      return ToggleResult.new(:nothing, "") if click.nothing?

      result = toggle(click)
      @last = LastAction.new(result.problem, TaskClick.none)
      result
    end

    #: (String url) -> void
    def follow(url)
      @last = LastAction.new(LinkOpener.new(File.dirname(@file.path), LinkOpener::XDG_OPEN).open(url), @last.undo)
      nil
    end

    # What the file held at the last read ("" when it cannot be read).
    #: () -> String
    def content
      @snapshot.content
    end

    # The file's name, shown in the header above the first heading.
    #: () -> String
    def name
      File.basename(@file.path)
    end

    # Everything the window may draw, for choosing which glyphs to load.
    #: () -> String
    def shown_text
      "#{@snapshot.content}#{@snapshot.problem}#{action_problem}"
    end

    # Shown above the document: why the file cannot be read, and why the
    # last click could not be saved or opened.
    #: () -> Array[String]
    def notices
      [@snapshot.problem, action_problem].reject(&:empty?)
    end

    private

    #: () -> Markdown::BlockList
    def parse
      Markdown::Parser.parse(@snapshot.content)
    end
  end
end
