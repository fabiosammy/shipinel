# frozen_string_literal: true

# How far through its tasks a document is: how many tasks it has and how
# many of them are checked. Tasks inside code fences are not tasks, so they
# never count.

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

      # For the daily nudge: "week.md · 33% done".
      #: (String name) -> String
      def done_line(name)
        "#{name} · #{percent}% done"
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
  end
end
