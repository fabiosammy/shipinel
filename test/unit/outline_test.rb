# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/outline"

# A page with three headings (levels 1, 2, 1) at 0, 300 and 600, the
# second with a task done of two; the outline panel in a 400 x 160 page
# area under a 40-pixel header, rows 27 pixels tall: room for three rows
# (7/10 of 160 is 112, less 16 of padding).
class OutlineTest < Minitest::Test
  STYLE = Shipinel::TextStyle.new(0, 20.0, 0)

  def content
    @content ||= Shipinel::DrawList.new.tap do |list|
      list.heading("Week", 0.0, 1)
      list.heading("Goal 1", 300.0, 2)
      2.times { |done| list.end_block(Shipinel::Markdown::Task.new(done, 0, "a", done.zero?)) }
      list.heading("Goal 2", 600.0, 1)
    end
  end

  def page(offset = 0.0)
    Shipinel::PageInView.new(content, Shipinel::Viewport.new(offset, Shipinel::Rect.new(0.0, 40.0, 400.0, 160.0)))
  end

  def panel(outline, offset = 0.0) = Shipinel::OutlinePanel.new(outline, page(offset), STYLE)

  def input(top, buttons = 0, keys = 0)
    Shipinel::Input.new(Shipinel::Point.new(50.0, top), buttons, 0.0, Shipinel::KeyPress.new(keys, ""))
  end

  PRESS = Shipinel::Input::DOWN | Shipinel::Input::PRESSED
  G = Shipinel::OutlineKeys::TOGGLE

  def opened(offset = 0.0) = Shipinel::Outline.none.after(input(0.0, 0, G), panel(Shipinel::Outline.none, offset))

  def test_g_opens_on_the_section_in_view
    assert_equal [true, 0, 1], [opened.open?, opened.selected, opened(350.0).selected]
  end

  # Rows start 8 pixels under the header (at 48): the second row is 75-102.
  def test_a_click_on_a_row_jumps_there_and_closes
    outline = opened
    jumped = outline.after(input(80.0, PRESS), panel(outline))

    assert_equal [false, 1, "goal-1"], [jumped.open?, jumped.target, jumped.spot(panel(jumped)).slug]
  end

  def test_a_click_outside_closes_without_jumping
    outline = opened
    closed = outline.after(input(180.0, PRESS), panel(outline))

    assert_equal [false, false], [closed.open?, closed.spot(panel(closed)).aimed?]
  end

  # Down moves the selection, stopping at the last row; Escape closes.
  def test_keys_move_and_close
    down = Shipinel::KeyPress::Moves::LINE_DOWN
    outline = opened
    3.times { outline = outline.after(input(0.0, 0, down), panel(outline)) }

    assert_equal [2, false],
                 [outline.selected, outline.after(input(0.0, 0, Shipinel::FindKeys::CLOSE), panel(outline)).open?]
  end

  # The rows: the level-2 heading indented; each with the tasks under it
  # (Week's include its subsection's).
  def test_the_panel_draws_each_heading
    overlay = Shipinel::DrawList.new
    panel(opened).add_to(overlay)
    runs = Array.new(overlay.size) { |position| overlay.at(position) }.grep(Shipinel::TextRun)

    assert_equal([["Week · 1 of 2", 16.0], ["Goal 1 · 1 of 2", 32.0], ["Goal 2", 16.0]], runs.map do |run|
      [run.text, run.rect.left]
    end)
  end

  def test_nothing_is_drawn_while_closed
    overlay = Shipinel::DrawList.new
    panel(Shipinel::Outline.none).add_to(overlay)

    assert_equal 0, overlay.size
  end

  def typed(text) = Shipinel::Input.new(Shipinel::Point.new(50.0, 0.0), 0, 0.0, Shipinel::KeyPress.new(0, text))
  def after(outline, input) = outline.after(input, panel(outline))

  # A typed "?" opens the help over the outline.
  def test_the_help_opens_over_the_outline
    helping = after(opened, typed("?"))

    assert_equal [true, false, true], [helping.help?, helping.open?, helping.shown?]
  end

  # ?, F1, Escape or a click close it.
  def test_the_help_closes
    helping = after(opened, typed("?"))
    closers = [typed("?"), input(0.0, 0, Shipinel::OutlineKeys::HELP), input(0.0, 0, Shipinel::FindKeys::CLOSE),
               input(80.0, PRESS)]

    assert_equal([false] * 4, closers.map { |closer| after(helping, closer).help? })
  end

  def test_f1_opens_the_help_and_other_keys_keep_it
    helping = after(Shipinel::Outline.none, input(0.0, 0, Shipinel::OutlineKeys::HELP))

    assert_equal [true, true], [helping.help?, after(helping, input(0.0, 0, Shipinel::KeyPress::Moves::LINE_DOWN)).help?]
  end

  def help_texts
    overlay = Shipinel::DrawList.new
    panel(after(Shipinel::Outline.none, typed("?"))).add_to(overlay)
    Array.new(overlay.size) { |position| overlay.at(position) }.grep(Shipinel::TextRun).map(&:text)
  end

  # The help covers the page area: its title, then a key and what it does.
  def test_the_help_panel_draws_the_keys
    texts = help_texts

    assert_equal [true, true],
                 [texts.first.start_with?("Shipinel #{Shipinel::VERSION}"), texts.include?("Tab, Shift+Tab")]
  end
end
