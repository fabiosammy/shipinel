# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_fonts"
require_relative "../../lib/shipinel/document_file"
require_relative "../../lib/shipinel/document_view"
require_relative "../../lib/shipinel/page"
require "tmpdir"

# The keyboard focus and the outline on a page: a 400 x 300 window over a
# plan with two sections, the second far enough down to scroll to.
class PageKeysTest < Minitest::Test
  class FakeScreen
    attr_accessor :keys, :typed

    def placement = Shipinel::WindowPlace.new(Shipinel::Rect.new(0.0, 0.0, 400.0, 300.0), false)

    def input
      Shipinel::Input.new(Shipinel::Point.new(0.0, 0.0), 0, 0.0, Shipinel::KeyPress.new(@keys || 0, @typed || ""))
    end
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
    runs = Array.new(frame.overlay_size) { |position| frame.overlay_at(position) }.grep(Shipinel::TextRun)
    runs.map(&:text).reject { |text| text == Shipinel::FindBar::STATUS }.last
  end

  def tasks_plan
    File.write(@path, "- [ ] a\n- [ ] b\n")
    @document.reload
  end

  def press_once(code)
    @screen.keys = press(code)
    pressed = frame
    @screen.keys = 0
    pressed
  end

  # Tab, Tab: the focus is on the second task, with a ring in the overlay;
  # Space hands that checkbox over as this frame's click.
  def test_tab_moves_the_focus_and_space_ticks
    tasks_plan
    press_once(Shipinel::Keyboard::Focusing::TAB)
    ringed = press_once(Shipinel::Keyboard::Focusing::TAB)
    rings = Array.new(ringed.overlay_size) { |position| ringed.overlay_at(position) }.grep(Shipinel::Box)
                 .count { |box| box.color == Shipinel::Theme::Focus::RING }

    assert_equal [4, 1], [rings, press_once(Shipinel::Keyboard::Focusing::SPACE).pressed.click.line_index]
  end

  def outline_after(*codes)
    codes.each { |code| press_once(code) }
    @page.redraw
    frame.marks.outline
  end

  # g opens the outline on the section in view (Goal 1, row 0); Down
  # selects Goal 2; Enter jumps there and closes it.
  def test_the_outline_jumps_to_a_section
    opened = outline_after(Shipinel::Keyboard::OUTLINE, Shipinel::Keyboard::Lines::DOWN)
    press_once(Shipinel::Keyboard::Finding::ENTER)
    jumped = frame

    assert_equal [true, 1, false, "Goal 2"], [opened.open?, opened.selected, jumped.marks.outline.open?, title(jumped)]
  end

  # While it is open, the keys move it, not the page: h does not hide the
  # header and Down does not scroll.
  def test_keys_go_to_the_open_outline
    outline_after(Shipinel::Keyboard::OUTLINE, Shipinel::Keyboard::HEADER, Shipinel::Keyboard::Lines::DOWN)

    assert_equal [true, 0.0], [@page.view.header?, @page.spot.offset]
  end

  # The panel's rows are in the overlay, with the counts; g closes it.
  def test_the_panel_lists_the_sections
    press_once(Shipinel::Keyboard::OUTLINE)
    @page.redraw
    shown = frame
    texts = Array.new(shown.overlay_size) { |position| shown.overlay_at(position) }.grep(Shipinel::TextRun).map(&:text)

    assert_equal [true, false], [texts.include?("Goal 2"), outline_after(Shipinel::Keyboard::OUTLINE).open?]
  end

  def type_once(text)
    @screen.typed = text
    frame
    @screen.typed = ""
  end

  # "?" opens the help; while it is open, h does not hide the header.
  def test_question_mark_opens_the_help
    type_once("?")
    press_once(Shipinel::Keyboard::HEADER)
    @page.redraw

    assert_equal [true, true], [frame.marks.outline.help?, @page.view.header?]
  end

  # With the find bar open, "?" is part of the query.
  def open_find
    @screen.keys = press(Shipinel::Keyboard::Finding::F) | Shipinel::KeyPress::Selecting::CONTROL
    frame
    @screen.keys = 0
  end

  def test_question_mark_is_typed_into_the_find_bar
    open_find
    type_once("?")
    @page.redraw
    shown = frame

    assert_equal [false, "?"], [shown.marks.outline.help?, shown.marks.search.query]
  end
end
