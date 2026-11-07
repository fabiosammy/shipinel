# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"
require_relative "../../lib/shipinel/app"

class AppTest < Minitest::Test
  # Records what App asks of the window; reports "closing" after two frames.
  class FakeScreen
    attr_reader :calls, :texts

    def initialize(opens: true)
      @opens = opens
      @calls = []
      @texts = []
      @frames = 0
    end

    def open(width, height, title)
      @calls << [:open, width, height, title]
    end

    def ready? = @opens

    def closing?
      @frames >= 2
    end

    def close = @calls << [:close]
    def begin_frame(color) = @calls << [:begin_frame, color]
    def load_font(slot, path, size) = @calls << [:load_font, slot, path, size]

    def end_frame
      @frames += 1
      @calls << [:end_frame]
    end

    def draw_text(text, at, style)
      @texts << [text, at.left, at.top, style.size]
    end
  end

  def setup
    @dir = Dir.mktmpdir("shipinel")
    @path = File.join(@dir, "semana.md")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def run_app(screen)
    options = Shipinel::Options.new(@path, nil, 20)
    Shipinel::App.new(screen, options, Shipinel::FontPaths.new("/f/sans.ttf", "/f/mono.ttf")).run
    screen
  end

  def test_opens_the_window_titled_shipinel
    screen = run_app(FakeScreen.new)

    assert_equal [:open, 440, 640, "shipinel"], screen.calls.first
    assert_equal [:close], screen.calls.last
  end

  def test_loads_body_and_mono_fonts_at_the_font_size
    loads = run_app(FakeScreen.new).calls.select { |call| call.first == :load_font }

    assert_equal [[:load_font, 0, "/f/sans.ttf", 20], [:load_font, 1, "/f/mono.ttf", 20]], loads
  end

  def test_draws_each_line_until_closed
    File.write(@path, "# Reunião\r\n- [ ] ação\n")
    texts = run_app(FakeScreen.new).texts

    assert_equal [["# Reunião", 16.0, 16.0, 20.0], ["- [ ] ação", 16.0, 44.0, 20.0]], texts.first(2)
    assert_equal 4, texts.size
  end

  def test_missing_file_shows_the_problem
    texts = run_app(FakeScreen.new).texts

    assert_match(/does not exist/, texts.first.first)
  end

  def test_window_that_does_not_open_ends_the_run
    screen = run_app(FakeScreen.new(opens: false))

    assert_equal 1, screen.calls.size
  end
end
