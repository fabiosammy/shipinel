# frozen_string_literal: true

# How far through its tasks a document is: how many tasks it has and how
# many of them are checked, and one that is still open (for the daily
# nudge). Tasks inside code fences are not tasks, so they never count.

require_relative "inline"

module Shipinel
  module Markdown
    # See the file comment. (Not `any?` or `count`: those names pull in
    # Spinel's widening builtins, docs/spinel-notes.md.)
    class TaskProgress
      attr_reader :done #: Integer
      attr_reader :total #: Integer

      #: () -> void
      def initialize
        @done = 0
        @total = 0
      end

      # Counts the block if it is a task; any other block is skipped.
      #: (Block block) -> void
      def add(block)
        return unless block.is_a?(Task)

        @total += 1
        @done += 1 if block.checked?
        nil
      end

      #: () -> bool
      def tasks?
        @total.positive?
      end

      #: () -> bool
      def complete?
        tasks? && @done == @total
      end

      # The checked share, from 0.0 to 1.0 (0.0 without tasks: 0 of at
      # least 1).
      #: () -> Float
      def share
        @done.to_f / divisor
      end

      # Rounded down, so 100% only shows once every task is checked.
      #: () -> Integer
      def percent
        @done * 100 / divisor
      end

      # Example: "12 of 40 tasks done · 30%".
      #: () -> String
      def label
        "#{@done} of #{@total} #{noun} done · #{percent}%"
      end

      # A section's count in the header: "3 of 8", or "" without tasks.
      #: () -> String
      def count_text
        tasks? ? "#{@done} of #{@total}" : ""
      end

      # The tray icon's tooltip.
      #: () -> String
      def tray_label
        tasks? ? label : "No tasks in this plan"
      end

      # For the daily nudge: "2 tasks still open".
      #: () -> String
      def open_label
        left = @total - @done
        "#{left} #{left == 1 ? 'task' : 'tasks'} still open"
      end

      # For the daily nudge: "week.md · 33% done", and on a second line an
      # open task that is not waiting, when there is one.
      #: (String name, String example) -> String
      def nudge_body(name, example)
        done_line = "#{name} · #{percent}% done"
        example.empty? ? done_line : "#{done_line}\nStill open: #{example}"
      end

      private

      #: () -> Integer
      def divisor
        [@total, 1].max
      end

      #: () -> String
      def noun
        @total == 1 ? "task" : "tasks"
      end
    end

    # The first open task not waiting on anything, as plain text without
    # its markup ("" when there is none). Tasks are not done in order, so
    # it is an example of what is left, not "the next one".
    class OpenExample
      attr_reader :text #: String

      #: () -> void
      def initialize
        @text = ""
      end

      # Keeps the first such task's text; looks at nothing after it.
      #: (Block block) -> void
      def add(block)
        @text = OpenExample.text_of(block) if @text.empty?
        nil
      end

      # A task's plain text when it is open and not waiting, else "" (so
      # the search goes on).
      #: (Block block) -> String
      def self.text_of(block)
        return "" unless Task.open?(block)

        text = block.text
        Task.waiting?(text) ? "" : Inline.parse(text).plain
      end
    end
  end
end
