# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/stop_signals"

class StopSignalsTest < Minitest::Test
  def test_nothing_received_until_a_stop
    signals = Shipinel::StopSignals.new

    refute_predicate signals, :received?
    signals.stop

    assert_predicate signals, :received?
  end

  def test_the_signals_are_term_int_and_hup
    assert_equal %w[TERM INT HUP], Shipinel::StopSignals.names
  end
end
