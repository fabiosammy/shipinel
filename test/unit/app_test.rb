# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_fonts"
require "fileutils"
require "tmpdir"
require "minitest/mock"
require_relative "../../lib/shipinel/app"

class AppTest < Minitest::Test
  # A window of a given height that closes after `frames` frames. It clicks
  # the first checkbox drawn on frame `click_on`, and turns the wheel by
  # `wheel` every frame.
  class FakeScreen
    attr_reader :calls, :text_tops

    attr_accessor :on_frame_end

    # broken: :window (it never opens) or :font (the body font fails).
    def initialize(frames: 2, click_on: nil, wheel: 0.0, broken: nil)
      @frames = frames
      @click_on = click_on
      @wheel = wheel
      @broken = broken
      @frame = 0
      @calls = []
      @text_tops = []
    end

    def open(place, title) = @calls << [:open, place.rect.width, place.rect.height, title]
    def ready? = @broken != :window
    def closing? = @frame >= @frames
    def close = @calls << [:close]
    def placement = Shipinel::WindowPlace.sized(440, 640)
    def input = Shipinel::Input.new(Shipinel::Point.new(0.0, 0.0), 0, @wheel, Shipinel::KeyPress.new(0, ""))
    def font_shim = (@font_shim ||= FakeShim.new(failing: @broken == :font ? PATHS_FAILING : []))
    def begin_frame(_color) = @pointed = false
    def texts_on(frame) = @texts.select { |text_frame, _text| text_frame == frame }.map(&:last)

    # The window system asks for a redraw on skipped frame `redraw_on`:
    # that frame's number is returned (truthy), any other gives nil.
    def skip_frame
      @calls << [:skip]
      end_frame
      [@redraw_on].compact.delete(@frame - 1)
    end

    attr_writer :redraw_on

    def end_frame
      @calls << [:end_frame]
      on_frame_end&.call(@frame)
      @frame += 1
    end

    def draw_rect(_rect, _color) = nil

    def draw_text(text, at, _style)
      @text_tops << [@frame, at.top]
      (@texts ||= []) << [@frame, text]
    end

    def draw_checkbox(_rect, _checked) = nil

    # The pointer clicks the first checkbox or link it is asked about on
    # frame `click_on`.
    def pointer_on(_rect)
      return :away if @pointed || @frame != @click_on

      @pointed = true
      :clicked
    end

    def use_hand_cursor(_hand) = nil
  end

  def setup
    @dir = Dir.mktmpdir("shipinel")
    @path = File.join(@dir, "semana.md")
    File.write(@path, "# Semana\n- [ ] Reunião\n")
  end

  # Running the app installs the stop signals' traps (StopSignals); the
  # test runner gets Ruby's own handlers back.
  def teardown
    FileUtils.remove_entry(@dir)
    Shipinel::StopSignals.names.each { |name| Signal.trap(name, "DEFAULT") }
  end

  # No notifications: the tests never run notify-send.
  CONFIG = Shipinel::Config.new("notify_save_failed=off\n")

  PATHS_FAILING = ["/s.ttf", "/b.ttf", "/i.ttf", "/m.ttf", "/e.ttf"].freeze

  def run_app(screen)
    Shipinel::App.new(screen, Shipinel::Launch.new(@path, Shipinel::View.starting_at(20), PATHS, CONFIG)).run
    screen
  end

  def test_opens_the_window_titled_shipinel_and_closes_it
    calls = run_app(FakeScreen.new).calls

    assert_equal [[:open, 440, 640, "shipinel"], [:close]], [calls.first, calls.last]
  end

  def test_loads_every_font_with_the_documents_characters_and_styles_checkboxes
    File.write(@path, "# Semana → 🤖\n")
    screen = run_app(FakeScreen.new)
    calls = screen.font_shim.calls

    assert_equal [[:use, [0x2192, 0x1F916]], [:load, 0, "/s.ttf", 32]], calls.first(2)
    assert_equal(5, calls.count { |call| call.first == :load })
  end

  def test_clicking_a_checkbox_toggles_the_task_in_the_file
    run_app(FakeScreen.new(click_on: 0))

    assert_equal "# Semana\n- [x] Reunião\n", File.read(@path)
  end

  # The wheel is read before drawing, so even the first frame moves by a
  # step. Lines are 39 apart from 16 down, below a header line 38.95 tall:
  # one step (48) hides the first line under the header (not drawn), so
  # the first drawn is the second, at 7 + 38.95.
  def test_wheel_scrolls_the_page
    File.write(@path, "linha\n\n" * 20)
    tops = run_app(FakeScreen.new(wheel: -1.0)).text_tops

    assert_equal [[0, 45.95], [1, 36.95]], [tops.first, tops.find { |frame, _top| frame == 1 }]
  end

  def test_window_that_does_not_open_ends_the_run_with_an_error
    screen = FakeScreen.new(broken: :window)
    error = assert_raises(Shipinel::WindowError) { run_app(screen) }

    assert_equal [1, Shipinel::App::NO_WINDOW], [screen.calls.size, error.message]
  end

  def test_each_font_that_does_not_load_is_a_notice
    notices = run_app(FakeScreen.new(broken: :font)).texts_on(0).select { |text| text.start_with?("\"/") }

    assert_equal ["\"/s.ttf\"", "\"/b.ttf\"", "\"/i.ttf\"", "\"/m.ttf\"", "\"/e.ttf\""], notices.map(&:strip)
  end

  READINGS = Array.new(11) { |reading| reading * 600 }

  # The clock is stubbed: 0 ms at start, then 600 ms later per reading, so
  # every frame is due to poll.
  def test_an_external_edit_shows_up_on_the_next_poll
    screen = FakeScreen.new(frames: 3)
    screen.on_frame_end = ->(frame) { File.write(@path, "# Domingo\n") if frame.zero? }
    times = READINGS.each
    Shipinel::Clock.stub(:now_ms, -> { times.next }) { run_app(screen) }

    assert_equal [["Semana", "Reunião", "0 of 1 task done · 0%", "semana.md"], ["Domingo", "semana.md"]],
                 [screen.texts_on(0), screen.texts_on(1)]
  end

  # A link to a place in the same file opens nothing, so no browser starts.
  def test_clicking_a_link_follows_it
    File.write(@path, "[topo](#topo)\n")
    screen = run_app(FakeScreen.new(click_on: 0))

    assert_equal "[topo](#topo)\n", File.read(@path)
    assert_equal ["topo", "semana.md"], screen.texts_on(0)
  end

  # Nothing changes after the first frame, busy or idle, so only that one
  # is drawn: the others wait for input.
  def test_an_unchanged_page_is_drawn_once
    screen = run_app(FakeScreen.new(frames: 40))
    drawn = screen.calls.count { |call| call.first == :end_frame } - screen.calls.count { |call| call.first == :skip }

    assert_equal [1, ["Semana", "Reunião", "0 of 1 task done · 0%", "semana.md"]], [drawn, screen.texts_on(0)]
    assert_empty screen.texts_on(1)
  end

  def test_a_redraw_the_window_system_asks_for_is_drawn
    screen = FakeScreen.new(frames: 40)
    screen.redraw_on = 34
    run_app(screen)

    assert_equal [[], %w[Semana Reunião]], [screen.texts_on(34), screen.texts_on(35).first(2)]
  end

  def state_file = Shipinel::StateFile.for(@path)

  # Size 24, scrolled 30 pixels into "Semana", in a 500 x 700 window: the
  # window opens at that size and glyphs load at 1.6 x 24 = 38 pixels.
  def test_opens_where_it_was_left
    state_file.write("section=semana\nwithin=30\noffset=30\nsize=24\nheader=1\nwidth=500\nheight=700\n")
    screen = run_app(FakeScreen.new(frames: 1))

    assert_equal [[:open, 500.0, 700.0, "shipinel"], 38], [screen.calls.first, screen.font_shim.calls[1].last]
  end

  # A real SIGTERM to this process after the first frame of a window that
  # would otherwise stay open for a thousand.
  def run_until_signalled
    screen = FakeScreen.new(frames: 1_000)
    screen.on_frame_end = ->(frame) { Process.kill("TERM", Process.pid) if frame.zero? }
    run_app(screen)
  end

  # The loop ends within a few frames, the way the close button ends it.
  def test_a_stop_signal_closes_the_window_and_saves
    calls = run_until_signalled.calls

    assert_equal [[:close], true, true], [calls.last, File.exist?(state_file.path), calls.count([:end_frame]) < 10]
  end

  def test_remembers_where_it_was_on_closing
    run_app(FakeScreen.new(frames: 1))

    assert_match(/\Asection=\nwithin=0.0\noffset=0.0\nsize=20\nheader=1\nwidth=440\nheight=640\n
                  nudged=\nday=\d{4}-\d{2}-\d{2}\n\z/x, state_file.read)
  end
end
