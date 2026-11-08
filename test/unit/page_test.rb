# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_fonts"
require_relative "../../lib/shipinel/document_file"
require_relative "../../lib/shipinel/document_view"
require_relative "../../lib/shipinel/page"
require "tmpdir"

# A 400 x 300 window over a plan with two sections, the second ("Goal 2")
# far enough down to scroll to.
class PageTest < Minitest::Test
  class FakeScreen
    attr_accessor :keys

    def placement = Shipinel::WindowPlace.new(Shipinel::Rect.new(0.0, 0.0, 400.0, 300.0), false)
    def input = Shipinel::Input.new(Shipinel::Point.new(0.0, 0.0), 0, 0.0, Shipinel::KeyPress.new(@keys || 0))
  end

  SOURCE = "# Goal 1\n\n#{"linha\n\n" * 12}# Goal 2\n\n#{"mais\n\n" * 12}".freeze

  def setup
    @dir = Dir.mktmpdir("shipinel")
    @path = File.join(@dir, "semana.md")
    File.write(@path, SOURCE)
    @document = Shipinel::DocumentView.new(Shipinel::DocumentFile.new(@path))
    @page = Shipinel::Page.new(Shipinel::View.starting_at(20), Shipinel::FontSet.new(FakeShim.new, PATHS))
    @page.load_fonts(SOURCE)
    @screen = FakeScreen.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def frame = @page.update(@screen.input, @screen.placement.area, @document)
  def press(code) = 1 << Shipinel::Keyboard.watched.find_index(code)

  def title(frame)
    Array.new(frame.overlay_size) { |position| frame.overlay_at(position) }.grep(Shipinel::TextRun).last.text
  end

  def test_header_names_the_file_until_a_heading_scrolls_past
    assert_equal "semana.md", title(frame)
  end

  def test_aimed_spot_is_reached_on_the_next_frame_and_named
    @page.aim(Shipinel::ScrollSpot.new("goal-2", 10.0, 0.0))
    reached = frame

    assert_equal ["Goal 2", "goal-2", 10.0], [title(reached), @page.spot.slug, @page.spot.within]
  end

  # 20 to 22 pixels: everything grows by 1.1, and the page stays 10 * 1.1
  # into Goal 2.
  def test_zoom_stays_in_the_same_section
    @page.aim(Shipinel::ScrollSpot.new("goal-2", 10.0, 0.0))
    frame
    @screen.keys = press(Shipinel::Keyboard::Zoom::EQUAL)
    frame
    spot = @page.spot

    assert_equal ["goal-2", 11.0, 22], [spot.slug, spot.within.round(1), @page.view.size]
  end
end
