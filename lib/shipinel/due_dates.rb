# frozen_string_literal: true

# How many open tasks are overdue (their date has passed) and how many are
# due today, for the tray icon's tooltip. A task's date is the first
# YYYY-MM-DD in its text, as the page marks it (Highlights); done tasks
# and other blocks are history and never count.

require_relative "day"
require_relative "highlights"
require_relative "markdown/block"

module Shipinel
  # See the file comment. (Not `count`: the name pulls in Spinel's
  # widening builtins, docs/spinel-notes.md.)
  class DueDates
    attr_reader :overdue #: Integer
    attr_reader :today #: Integer

    # @rbs @day: Day

    #: (Day day) -> void
    def initialize(day)
      @day = day
      @overdue = 0
      @today = 0
    end

    # The open tasks of `blocks`, on `day`.
    #: (Markdown::BlockList blocks, Day day) -> DueDates
    def self.of(blocks, day)
      dates = DueDates.new(day)
      blocks.size.times { |position| dates.add(blocks.at(position)) }
      dates
    end

    # Counts the block if it is an open task with a past or today's date.
    #: (Markdown::Block block) -> void
    def add(block)
      return unless Markdown::Task.open?(block)

      date = Highlights.date_in(block.text)
      @overdue += 1 if @day.later_than?(date)
      @today += 1 if @day.on?(date)
      nil
    end

    # `label` followed by what needs attention: "4 of 14 tasks done · 28% ·
    # 2 overdue · 1 due today"; `label` alone when nothing does.
    #: (String label) -> String
    def after(label)
      [label, overdue_text, today_text].reject(&:empty?).join(" · ")
    end

    private

    #: () -> String
    def overdue_text
      @overdue.zero? ? "" : "#{@overdue} overdue"
    end

    #: () -> String
    def today_text
      @today.zero? ? "" : "#{@today} due today"
    end
  end
end
