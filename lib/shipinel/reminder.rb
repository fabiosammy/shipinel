# frozen_string_literal: true

# The notifications the config asks for: once a day at notify_daily, how
# many tasks are still open (sent on the first chore at or after that time,
# so a window opened later that day still gets it), and a notice when a
# click could not be saved. The day of the last nudge is saved with the
# plan's state, so a restart does not send it twice.

require_relative "config"
require_relative "markdown/task_progress"
require_relative "notifier"

module Shipinel
  # The local date and time of day: "2026-11-08", "17:30".
  class WallTime
    attr_reader :date #: String
    attr_reader :time #: String

    #: (String date, String time) -> void
    def initialize(date, time)
      @date = date
      @time = time
    end

    #: () -> WallTime
    def self.now
      now = Time.now
      WallTime.new(now.strftime("%Y-%m-%d"), now.strftime("%H:%M"))
    end
  end

  # See the file comment.
  class Reminder
    # The date of the last daily nudge ("" for never).
    attr_reader :nudged #: String

    # @rbs @settings: NotifySettings
    # @rbs @notifier: Notifier

    #: (NotifySettings settings, Notifier notifier, String nudged) -> void
    def initialize(settings, notifier, nudged)
      @settings = settings
      @notifier = notifier
      @nudged = nudged
    end

    # Called every chore. HH:MM strings compare in time order.
    #: (WallTime now, Markdown::TaskProgress progress, String name) -> void
    def tick(now, progress, name)
      return unless due?(now)

      @nudged = now.date
      tell(progress.open_label, progress.done_line(name)) unless progress.complete?
    end

    # After a click on a checkbox: `problem` is "" when it was saved.
    #: (String problem) -> void
    def save_failed(problem)
      tell("Shipinel could not save", problem) if @settings.save_failed? && !problem.empty?
    end

    private

    # A time is set, it has come, and today has had no nudge yet.
    #: (WallTime now) -> bool
    def due?(now)
      daily = @settings.daily_at
      !daily.empty? && now.time >= daily && @nudged != now.date
    end

    #: (String summary, String body) -> void
    def tell(summary, body)
      problem = @notifier.show(summary, body)
      warn "shipinel: #{problem}" unless problem.empty?
    end
  end
end
