# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"
require_relative "../../lib/shipinel/app"

class AppTest < Minitest::Test
  # A window of a given height that closes after `frames` frames. It clicks
  # the first checkbox drawn on frame `click_on`, and turns the wheel by
  # `wheel` every frame.
  class FakeScreen
    attr_reader :calls, :text_tops

    def initialize(frames: 2, click_on: nil, wheel: 0.0, opens: true)
      @frames = frames
      @click_on = click_on
      @wheel = wheel
      @opens = opens
      @frame = 0
      @calls = []
      @text_tops = []
    end

    def open(width, height, title) = @calls << [:open, width, height, title]
    def ready? = @opens
    def closing? = @frame >= @frames
    def close = @calls << [:close]
    def area = Shipinel::Rect.new(0.0, 0.0, 440.0, 100.0)
    def wheel_move = @wheel
    def load_font(slot, path, size) = @calls << [:load_font, slot, path, size]
    def style_checkboxes(*colors) = @calls << [:style_checkboxes, *colors]
    def text_measure = self
    def text_width(text, style) = text.size * style.size * 0.5
    def begin_frame(_color) = @clicked = false
    def end_frame = @frame += 1
    def draw_rect(_rect, _color) = nil
    def draw_text(_text, at, _style) = (@text_tops << [@frame, at.top])

    def checkbox_clicked?(_rect, _checked)
      return false if @clicked || @frame != @click_on

      @clicked = true
    end
  end

  def setup
    @dir = Dir.mktmpdir("shipinel")
    @path = File.join(@dir, "semana.md")
    File.write(@path, "# Semana\n- [ ] Reunião\n")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def run_app(screen)
    Shipinel::App.new(screen, @path,
                      Shipinel::Styles.new(20.0)).run(Shipinel::FontPaths.new("/s.ttf", "/b.ttf", "/m.ttf"))
    screen
  end

  def test_opens_the_window_titled_shipinel_and_closes_it
    calls = run_app(FakeScreen.new).calls

    assert_equal [[:open, 440, 640, "shipinel"], [:close]], [calls.first, calls.last]
  end

  def test_loads_three_fonts_at_the_largest_text_size_and_styles_checkboxes
    calls = run_app(FakeScreen.new).calls[1..4]

    assert_equal [[:load_font, 0, "/s.ttf", 32], [:load_font, 2, "/b.ttf", 32], [:load_font, 1, "/m.ttf", 32]],
                 calls.first(3)
    assert_equal :style_checkboxes, calls.last.first
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
    assert_equal 1, run_app(FakeScreen.new(opens: false)).calls.size
  end
end
