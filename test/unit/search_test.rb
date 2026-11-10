# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_fonts"
require_relative "../../lib/shipinel/search"

# Finding text on a page of two lines: "Ship the " "export" on the first
# (the second word bold), "then the demo" on the second. FakeShim fonts
# make every character 10 pixels wide at size 20.
class SearchTest < Minitest::Test
  STYLE = Shipinel::TextStyle.new(0, 20.0, 0)
  FONTS = fake_font_set

  def text_run(text, left, top)
    Shipinel::TextRun.new(text, Shipinel::Rect.new(left, top, text.size * 10.0, 27.0), STYLE)
  end

  def content
    @content ||= Shipinel::DrawList.new.tap do |list|
      list.add(text_run("Ship the ", 40.0, 0.0))
      list.add(text_run("export", 130.0, 0.0))
      list.add(Shipinel::Checkbox.new(Shipinel::Rect.new(16.0, 32.0, 17.0, 17.0), Shipinel::TaskClick.new(1, false)))
      list.add(text_run("then the Demo", 40.0, 27.0))
    end
  end

  def matches(query) = Shipinel::Matches.of(content, query, FONTS)
  def tops_and_lefts(found) = Array.new(found.pieces) { |piece| [found.rect_at(piece).top, found.rect_at(piece).left] }

  def test_page_text_joins_lines_with_a_space_and_folds_case
    assert_equal "ship the export then the demo", Shipinel::PageText.of(content).text
  end

  # Inside words too: "then" holds one.
  def test_every_match_case_insensitive
    found = matches("THE")

    assert_equal [3, [[0.0, 90.0], [27.0, 40.0], [27.0, 90.0]]], [found.total, tops_and_lefts(found)]
  end

  # "the export" crosses from the first run into the bold one: one match,
  # two pieces; the second piece covers all of "export".
  def test_a_match_across_runs_has_a_piece_in_each
    found = matches("the export")

    assert_equal [1, [[0.0, 90.0], [0.0, 130.0]], 60.0], [found.total, tops_and_lefts(found), found.rect_at(1).width]
  end

  # Wrapped over two lines, a phrase is still found.
  def test_a_match_across_lines
    assert_equal [[0.0, 130.0], [27.0, 40.0]], tops_and_lefts(matches("export then"))
  end

  def test_nothing_found
    assert_equal [0, 0, 0], [matches("pizza").total, matches("   ").total, matches("").total]
  end

  def test_first_match_below_a_page_position
    found = matches("the")

    assert_equal [0, 1, 0], [found.first_below(0.0), found.first_below(10.0), found.first_below(100.0)]
    assert_in_delta(27.0, found.rect_of(2).top)
  end

  # Keys for the find bar: these bits and this typed text.
  def keys(bits, typed = "") = Shipinel::FindKeys.new(bits, typed)

  OPEN = Shipinel::FindKeys::OPEN | Shipinel::KeyPress::Selecting::CONTROL

  def open_with(typed)
    Shipinel::Search.none.after(keys(OPEN), content, FONTS).after(keys(0, typed), content, FONTS)
  end

  def test_ctrl_f_opens_an_empty_bar_and_typing_finds
    search = open_with("de")

    assert_equal [true, "de", 1], [search.open?, search.query, search.total]
  end

  def test_backspace_takes_a_character_back
    search = open_with("thex").after(keys(Shipinel::FindKeys::ERASE), content, FONTS)

    assert_equal ["the", 3], [search.query, search.total]
  end

  # Enter goes round the three matches: 1, 2, then 0 again; Shift+Enter
  # goes back, from the first to the last.
  def test_enter_steps_through_the_matches_round_the_ends
    assert_equal [1, 2, 0, 0, 2], [stepped(1), stepped(1, 1), stepped(1, 1, 1), stepped(1, -1), stepped(-1)]
  end

  # The bar on "the" after Enter (1) or Shift+Enter (-1), in turn.
  def stepped(*steps)
    enter = Shipinel::FindKeys::ENTER
    steps.reduce(open_with("the")) do |search, step|
      search.after(keys(step.positive? ? enter : enter | Shipinel::FindKeys::SHIFT), content, FONTS)
    end.current
  end

  def test_escape_closes_and_keys_do_nothing_while_closed
    closed = open_with("the").after(keys(Shipinel::FindKeys::CLOSE), content, FONTS)

    assert_equal [false, false], [closed.open?, Shipinel::Search.none.after(keys(0, "x"), content, FONTS).open?]
  end

  # The same query on a page laid out again finds anew, from the first match.
  def test_a_new_layout_finds_again
    search = open_with("the")
    other = Shipinel::DrawList.new.tap { |list| list.add(content.at(3)) }

    refute_same search.after(keys(0), other, FONTS).matches, search.matches
  end

  # In a 100-pixel window scrolled to 200, a match at 27 is out of view:
  # the window goes to put it a third of the way down (never above 0).
  def test_aim_shows_the_current_match
    search = open_with("demo")
    far = Shipinel::Viewport.new(200.0, Shipinel::Rect.new(0.0, 0.0, 400.0, 100.0))
    near = Shipinel::Viewport.new(0.0, Shipinel::Rect.new(0.0, 0.0, 400.0, 100.0))

    assert_equal [0.0, false], [search.aim(far).offset, search.aim(near).aimed?]
  end

  # Found anew, the bar starts at the first match below the window's top;
  # the same matches keep their place.
  def test_placed_from_the_top_of_the_window
    search = open_with("the")
    below = Shipinel::Viewport.new(10.0, Shipinel::Rect.new(0.0, 0.0, 400.0, 100.0))
    placed = search.placed(Shipinel::Search.none, below)

    assert_equal [1, 1, true, false], [placed.current, placed.placed(placed, below).current,
                                       placed.same_as?(placed.placed(placed, below)), placed.same_as?(search)]
  end
end
