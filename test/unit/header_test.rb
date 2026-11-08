# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_fonts"
require_relative "../../lib/shipinel/header"
require_relative "../../lib/shipinel/markdown/parser"

# A 400-pixel-wide window, body text 20: status text 17, line 22.95; the
# fake font is 0.5 x size wide per character (8.5 pixels). The week is half
# gone (expected 0.5) unless a test says otherwise.
class HeaderTest < Minitest::Test
  VIEW = Shipinel::View.starting_at(20)

  def header(source, view = VIEW, expected: 0.5)
    progress = Shipinel::WeekProgress.new(Shipinel::Markdown::Parser.parse(source).task_progress, expected)
    Shipinel::Header.new(view, progress, 400.0, "")
  end

  def line(title, count = "") = Shipinel::SectionLine.new(title, count)

  def commands(source, section: line("semana.md"), view: VIEW, expected: 0.5)
    page = Shipinel::DrawList.new
    header(source, view, expected: expected).titled(section, fake_font_set).add_to(page)
    Array.new(page.size) { |position| page.at(position) }
  end

  def rect(command) = [command.rect.left, command.rect.top, command.rect.width, command.rect.height].map { it.round(2) }

  def test_without_tasks_only_the_section_line
    band, title = commands("texto\n")

    assert_equal [[0.0, 0.0, 400.0, 38.95], "semana.md", [16.0, 8.0]], [rect(band), title.text, rect(title).first(2)]
  end

  def test_with_tasks_label_bar_and_section_line
    band, label, track, fill, _pace, title = commands("- [x] a\n- [ ] b\n- [ ] c\n- [ ] d\n", section: line("Goal 1"))

    assert_equal [[0.0, 0.0, 400.0, 81.9], "1 of 4 tasks done · 25%", "Goal 1", 50.95],
                 [rect(band), label.text, title.text, title.rect.top.round(2)]
    assert_equal [[16.0, 38.95, 368.0, 4.0], [16.0, 38.95, 92.0, 4.0]], [rect(track), rect(fill)]
  end

  def test_section_line_is_muted
    assert_equal Shipinel::Theme::Ink::MUTED, commands("texto\n").last.style.color
  end

  def test_bar_turns_green_when_everything_is_done
    assert_equal Shipinel::Theme::Progress::COMPLETE, commands("- [x] a\n")[3].color
  end

  def test_a_long_title_is_cut_to_fit
    title = commands("texto\n",
                     section: line("Goal 1 — Drata monitoring tests (Consolidate datadog P-DOS-224, SOC 2)")).last.text

    assert_equal ["Goal 1 — Drata monitoring tests (Consolida…", true],
                 [title, (title.size * 8.5) <= 368.0]
  end

  # Half the week gone: the tick sits mid-bar, 2 wide, reaching 2 above
  # and below the 4-pixel bar.
  def test_pace_tick_where_the_week_is
    pace = commands("- [x] a\n- [ ] b\n")[4]

    assert_equal [[199.0, 36.95, 2.0, 8.0], Shipinel::Theme::Pace::MARK], [rect(pace), pace.color]
  end

  # 2 of 4 done (50%) at 50% of the week is on pace; at 80% of the week it
  # is more than a day (20%) behind.
  def test_bar_turns_amber_more_than_a_day_behind
    source = "- [x] a\n- [x] b\n- [ ] c\n- [ ] d\n"

    assert_equal [Shipinel::Theme::Progress::FILL, Shipinel::Theme::Pace::BEHIND],
                 [commands(source)[3].color, commands(source, expected: 0.8)[3].color]
  end

  def test_section_count_follows_the_title_and_keeps_room
    long = "Goal 1 — Drata monitoring tests (Consolidate datadog P-DOS-224, SOC 2)"

    assert_equal ["Goal 1 · 3 of 8", "Goal 1 — Drata monitoring tests (… · 3 of 8"],
                 [commands("texto\n", section: line("Goal 1", "3 of 8")).last.text,
                  commands("texto\n", section: line(long, "3 of 8")).last.text]
  end

  def test_hidden_header_takes_no_room
    hidden = Shipinel::View.new(20, 20, false)

    assert_equal [0.0, []], [header("- [ ] a\n", hidden).height, commands("- [ ] a\n", view: hidden)]
  end
end
