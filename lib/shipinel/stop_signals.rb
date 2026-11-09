# frozen_string_literal: true

# The signals that ask Shipinel to stop: TERM (kill, a logout, systemd),
# INT (Ctrl+C in the terminal it was started from) and HUP (the terminal
# closed). Each only sets a flag; the loop sees it on its next frame and
# ends the way the close button does, saving where the window was.
# Without the traps, the signal ended the app at once with a
# "SIGTERM (SignalException)" line, and the last half second of state was
# lost.

module Shipinel
  # See the file comment.
  class StopSignals
    # @rbs @received: bool

    #: () -> void
    def initialize
      @received = false
    end

    # A method, not a constant: Spinel does not type constants.
    #: () -> Array[String]
    def self.names
      %w[TERM INT HUP]
    end

    # Installs the traps (checked in docs/spinel-notes.md).
    #: () -> void
    def watch
      StopSignals.names.each { |name| Signal.trap(name) { stop } }
      nil
    end

    # What a trap does; also called directly in tests.
    #: () -> void
    def stop
      @received = true
      nil
    end

    #: () -> bool
    def received?
      @received
    end
  end
end
