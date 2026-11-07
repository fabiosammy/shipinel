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
    def area = Shipinel::Rect.new(0.0, 0.0, @width, 300.0)
    def mouse = Shipinel::MouseState.new(Shipinel::Point.new(0.0, 0.0), 0, 0.0)
  end

  def setup
    @dir = Dir.mktmpdir("shipinel")
    @path = File.join(@dir, "semana.md")
    File.write(@path, "# Semana\n- [ ] Reunião\n")
    @document = Shipinel::DocumentView.new(Shipinel::DocumentFile.new(@path))
    @shim = FakeShim.new
    @page = Shipinel::Page.new(Shipinel::Styles.new(20.0), Shipinel::FontSet.new(@shim, PATHS))
    @screen = FakeScreen.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  # Measured widths so far, after one more frame.
  def measured_after_frame
    @page.update(@screen, @document)
    @shim.measured
  end

  def test_same_document_and_width_reuse_the_layout
    first = measured_after_frame

    assert_equal first, measured_after_frame
  end

  def test_a_new_width_lays_out_again
    first = measured_after_frame
    @screen.width = 300.0

    assert_operator measured_after_frame, :>, first
  end

  def test_a_changed_file_lays_out_again
    first = measured_after_frame
    File.write(@path, "# Domingo\n")
    @document.reload

    assert_operator measured_after_frame, :>, first
  end

  def test_new_characters_reload_the_fonts_and_lay_out_again
    first = measured_after_frame
    @page.refresh_fonts("→")

    assert_operator measured_after_frame, :>, first
  end

  # The pointer never moves here: the first frames are busy (it appeared),
  # then idle frames are not built until the file changes.
  def test_idle_frames_are_not_built_until_the_page_changes
    frames = Array.new(40) { @page.update(@screen, @document) }
    File.write(@path, "# Domingo\n")
    @document.reload

    assert_equal [false, true, false], [frames.first.nil?, frames.last.nil?, @page.update(@screen, @document).nil?]
  end
end
