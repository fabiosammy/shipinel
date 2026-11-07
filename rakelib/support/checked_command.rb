# frozen_string_literal: true

# Runs one external tool for a rake task and fails the task on a non-zero
# exit or on any warning line. Spinel and spin have no -Werror switch, so
# their output is the only place a widen or build warning shows up.

require "open3"

# See the file comment.
module CheckedCommand
  WARNING_LINE = /^.*warning.*$/i

  # Returns stdout only: `spin flags` prints compile progress on stderr, and
  # that must not end up in the flags handed to spinel. Both streams are
  # printed and checked for warnings.
  def self.run(*command)
    stdout, stderr, status = Open3.capture3(*command)
    print stdout
    $stderr.print stderr
    raise "#{command.join(' ')} exited with #{status.exitstatus}" unless status.success?

    warning = "#{stdout}#{stderr}"[WARNING_LINE]
    raise "#{command.first} printed a warning: #{warning}" if warning

    stdout
  end
end
