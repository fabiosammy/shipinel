# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/poller"

class PollerTest < Minitest::Test
  def test_not_due_within_the_interval
    refute Shipinel::Poller.new(1000).due?(1499)
  end

  def test_due_once_the_interval_has_passed_then_waits_again
    poller = Shipinel::Poller.new(1000)

    assert_equal [true, false, true], [poller.due?(1500), poller.due?(1900), poller.due?(2000)]
  end

  def test_clock_counts_up_in_milliseconds
    first = Shipinel::Clock.now_ms

    assert_operator Shipinel::Clock.now_ms, :>=, first
  end
end
