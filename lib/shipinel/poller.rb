# frozen_string_literal: true

# When to re-read the file: about every 500 ms. Files are tiny, so reading
# and comparing the content is cheap, and it also notices editors that save
# by writing a new file and renaming it over the old one (which inotify on
# the old file would miss).

module Shipinel
  # Milliseconds from the monotonic clock, which never jumps when the
  # wall clock is changed.
  module Clock
    #: () -> Integer
    def self.now_ms
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
    end
  end

  # See the file comment.
  class Poller
    INTERVAL_MS = 500

    # @rbs @last: Integer

    #: (Integer now) -> void
    def initialize(now)
      @last = now
    end

    # True once per interval; the next interval starts now.
    #: (Integer now) -> bool
    def due?(now)
      return false if now - @last < INTERVAL_MS

      @last = now
      true
    end
  end
end
