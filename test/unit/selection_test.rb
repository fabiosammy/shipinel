# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/frame"
require_relative "../../lib/shipinel/task_toggler"

# Text selected with the mouse: which words, in what order, and how a drag
# goes. The page has two lines of three words (27 px tall, words 60 px
# apart) and a checkbox; the window shows it from the top, no header.
class SelectionTest < Minitest::Test
  STYLE = Shipinel::TextStyle.new(0, 20.0, 0)

  def word(text, line, column)
    Shipinel::TextRun.new("#{text} ", Shipinel::Rect.new(40.0 + (column * 60.0), line * 27.0, 50.0, 27.0), STYLE)
  end

  def content
    @content ||= Shipinel::DrawList.new.tap do |list|
      [%w[Ship the export], %w[then the demo]].each_with_index do |words, line|
        words.each_with_index { |text, column| list.add(word(text, line, column)) }
      end
      list.add(Shipinel::Checkbox.new(Shipinel::Rect.new(16.0, 5.0, 17.0, 17.0), Shipinel::TaskClick.new(0, false)))
    end
  end

  WINDOW = Shipinel::Viewport.new(0.0, Shipinel::Rect.new(0.0, 0.0, 400.0, 600.0))
  PRESS = Shipinel::Input::DOWN | Shipinel::Input::PRESSED

  def frame = Shipinel::Frame.new(content, Shipinel::DrawList.new, WINDOW)
  def point(left, top) = Shipinel::Point.new(left, top)

  def input(left, top, buttons, keys = 0)
    Shipinel::Input.new(point(left, top), buttons, 0.0, Shipinel::KeyPress.new(keys, ""))
  end

  # From the middle of "the" on the first line to the middle of "the" on
  # the second, as a drag would leave it.
  def selection(from, to) = Shipinel::Selection.new(content, from, to, :done)

  def test_selects_from_start_to_end_in_reading_order
    assert_equal "the export\nthen the", selection(point(100.0, 10.0), point(170.0, 40.0)).text
  end

  def test_an_upward_drag_selects_the_same_words
    assert_equal "the export\nthen the", selection(point(170.0, 40.0), point(100.0, 10.0)).text
  end

  def test_select_all_takes_every_word
    assert_equal "Ship the export\nthen the demo", Shipinel::Selection.all(content).text
  end

  def test_nothing_selected_is_no_text
    assert_equal "", Shipinel::Selection.none.text
  end

  # The selections a press on "Ship", a drag past the middle of "export"
  # and a release leave, frame by frame.
  def drag
    page = frame
    steps = [input(45.0, 10.0, PRESS), input(195.0, 10.0, Shipinel::Input::DOWN), input(195.0, 10.0, 0),
             input(195.0, 10.0, 0)]
    steps.each_with_object([Shipinel::Selection.none]) { |step, made| made << made.last.after(step, page) }.drop(1)
  end

  def test_a_drag_goes_through_its_states
    assert_equal %i[dragging dragging released done], drag.map(&:state)
  end

  def test_a_drag_selects_its_words
    assert_equal "Ship the export", drag.last.text
  end

  def test_a_click_without_a_drag_selects_nothing
    page = frame
    pressed = Shipinel::Selection.none.after(input(45.0, 10.0, PRESS), page)

    refute_predicate pressed.after(input(45.0, 10.0, 0), page), :active?
  end

  # A press on the checkbox is a click on it, not the start of a selection,
  # and it clears the one there was.
  def test_a_press_on_a_checkbox_clears_the_selection
    pressed = Shipinel::Selection.all(content).after(input(20.0, 10.0, PRESS), frame)

    refute_predicate pressed, :active?
  end

  def test_ctrl_a_selects_everything
    keys = (1 << Shipinel::Keyboard.watched.index(Shipinel::Keyboard::Selecting::A)) | Shipinel::KeyPress::Selecting::CONTROL

    assert_equal "Ship the export\nthen the demo", Shipinel::Selection.none.after(input(0.0, 0.0, 0, keys), frame).text
  end

  # The file changed: the old page's words are gone.
  def test_a_new_layout_drops_the_selection
    other = Shipinel::Frame.new(Shipinel::DrawList.new, Shipinel::DrawList.new, frame.view)

    refute_predicate Shipinel::Selection.all(content).after(input(0.0, 0.0, 0), other), :active?
  end

  def test_a_selection_is_part_of_the_look
    page = frame
    rest = page.look(input(300.0, 300.0, 0))

    selected = page.showing(Shipinel::Marks.none.with_selection(Shipinel::Selection.all(content)))

    refute rest.same_as?(selected.look(input(300.0, 300.0, 0)))
  end
end
