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

    def open(width, height, title) = @calls << [:open, width, height, title]
    def ready? = @broken != :window
    def closing? = @frame >= @frames
    def close = @calls << [:close]
    def area = Shipinel::Rect.new(0.0, 0.0, 440.0, 100.0)
    def mouse = Shipinel::MouseState.new(Shipinel::Point.new(0.0, 0.0), 0, @wheel)
    def style_checkboxes(*colors) = @calls << [:style_checkboxes, *colors]
    def font_shim = (@font_shim ||= FakeShim.new(failing: @broken == :font ? PATHS_FAILING : []))
    def begin_frame(_color) = @pointed = false
    def texts_on(frame) = @texts.select { |text_frame, _text| text_frame == frame }.map(&:last)

    def end_frame
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

  def teardown
    FileUtils.remove_entry(@dir)
  end

  PATHS_FAILING = ["/s.ttf", "/b.ttf", "/i.ttf", "/m.ttf", "/e.ttf"].freeze

  def run_app(screen)
    Shipinel::App.new(screen, @path, Shipinel::Styles.new(20.0), PATHS).run
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
    assert_equal [5, :style_checkboxes], [calls.count { |call| call.first == :load }, screen.calls[1].first]
  end

  def test_clicking_a_checkbox_toggles_the_task_in_the_file
    run_app(FakeScreen.new(click_on: 0))

    assert_equal "# Semana\n- [x] Reunião\n", File.read(@path)
  end

  # The wheel is read before drawing, so even the first frame moves by a step.
  def test_wheel_scrolls_the_page
    File.write(@path, "linha\n\n" * 20)
    tops = run_app(FakeScreen.new(wheel: -1.0)).text_tops

    assert_equal [[0, -32.0], [1, -80.0]], [tops.first, tops.find { |frame, _top| frame == 1 }]
  end

  def test_window_that_does_not_open_ends_the_run
    assert_equal 1, run_app(FakeScreen.new(broken: :window)).calls.size
  end

  def test_each_font_that_does_not_load_is_a_notice
    notices = run_app(FakeScreen.new(broken: :font)).texts_on(0).select { |text| text.start_with?("\"/") }

    assert_equal ["\"/s.ttf\"", "\"/b.ttf\"", "\"/i.ttf\"", "\"/m.ttf\"", "\"/e.ttf\""], notices.map(&:strip)
  end

  # The clock is stubbed: 0 ms at start, then 600 ms later per frame, so
  # every frame is due to poll.
  def test_an_external_edit_shows_up_on_the_next_poll
    screen = FakeScreen.new(frames: 3)
    screen.on_frame_end = ->(frame) { File.write(@path, "# Domingo\n") if frame.zero? }
    times = [0, 600, 1200, 1800].each
    Shipinel::Clock.stub(:now_ms, -> { times.next }) { run_app(screen) }

    assert_equal [["Semana", "Reunião", "0 of 1 task done · 0%"], ["Domingo"]], [screen.texts_on(0), screen.texts_on(1)]
  end

  # A link to a place in the same file opens nothing, so no browser starts.
  def test_clicking_a_link_follows_it
    File.write(@path, "[topo](#topo)\n")
    screen = run_app(FakeScreen.new(click_on: 0))

    assert_equal "[topo](#topo)\n", File.read(@path)
    assert_equal ["topo"], screen.texts_on(1)
  end
end
