# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_fonts"
require_relative "../../lib/shipinel/document_file"
require_relative "../../lib/shipinel/document_view"
require_relative "../../lib/shipinel/page"
require "tmpdir"

# The page is laid out again only when the blocks, width, notices or fonts
# change: scrolling and pointing reuse the layout.
class ContentCacheTest < Minitest::Test
  class FakeScreen
    attr_accessor :width

    def initialize = @width = 400.0
    def placement = Shipinel::WindowPlace.new(Shipinel::Rect.new(0.0, 0.0, @width, 300.0), false)
    attr_writer :keys

    def input = Shipinel::Input.new(Shipinel::Point.new(0.0, 0.0), 0, 0.0, Shipinel::KeyPress.new(@keys || 0))
  end

  def setup
    @dir = Dir.mktmpdir("shipinel")
    @path = File.join(@dir, "semana.md")
    File.write(@path, "# Semana\n- [ ] Reunião\n")
    @document = Shipinel::DocumentView.new(Shipinel::DocumentFile.new(@path))
    @shim = FakeShim.new
    @page = Shipinel::Page.new(Shipinel::View.starting_at(20), Shipinel::FontSet.new(@shim, PATHS))
    @screen = FakeScreen.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  # The laid-out page of the next frame (the first frames are busy, so
  # each one is built).
  def update = @page.update(@screen.input, @screen.placement.area, @document)
  def laid_out = update.content

  def test_same_document_and_width_reuse_the_layout
    assert_same laid_out, laid_out
  end

  def test_a_new_width_lays_out_again
    first = laid_out
    @screen.width = 300.0

    refute_same first, laid_out
  end

  def test_a_changed_file_lays_out_again
    first = laid_out
    File.write(@path, "# Domingo\n")
    @document.reload

    refute_same first, laid_out
  end

  def test_new_characters_reload_the_fonts_and_lay_out_again
    first = laid_out
    @page.refresh_fonts("→")

    refute_same first, laid_out
  end

  # The pointer never moves here: the first frames are busy (it appeared),
  # then idle frames are not built until the file changes.
  def test_idle_frames_are_not_built_until_the_page_changes
    frames = Array.new(40) { update }
    File.write(@path, "# Domingo\n")
    @document.reload

    assert_equal [false, true, false], [frames.first.nil?, frames.last.nil?, update.nil?]
  end

  def press(code) = 1 << Shipinel::Keyboard.watched.find_index(code)

  # Glyphs are loaded at the level 1 heading size: 1.6 x 20, then 1.6 x 22.
  def test_zoom_reloads_the_fonts_bigger_and_lays_out_again
    @page.load_fonts("")
    update
    @screen.keys = press(Shipinel::Keyboard::Zoom::EQUAL)
    update
    sizes = @shim.calls.select { |call| call.first == :load }.map(&:last).uniq

    assert_equal [32, 35], sizes
  end

  # The header shows "0 of 1 task done"; h hides it, so the page starts
  # at the top of the window.
  def test_h_hides_the_header
    shown = update.view.top
    @screen.keys = press(Shipinel::Keyboard::HEADER)
    hidden = update.view.top

    assert_equal [true, 0.0], [shown.positive?, hidden]
  end
end
