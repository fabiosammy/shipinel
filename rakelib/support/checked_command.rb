# frozen_string_literal: true

# Runs one external tool for a rake task and fails the task on a non-zero
# exit or on any warning line. Spinel and spin have no -Werror switch, so
# their output is the only place a widen or build warning shows up.

require "open3"

# See the file comment.
module CheckedCommand
  WARNING_LINE = /^.*warning.*$/i

  def self.run(*command)
    output, status = Open3.capture2e(*command)
    print output
    raise "#{command.join(' ')} exited with #{status.exitstatus}" unless status.success?

    warning = output[WARNING_LINE]
    raise "#{command.first} printed a warning: #{warning}" if warning

    output
  end
end
