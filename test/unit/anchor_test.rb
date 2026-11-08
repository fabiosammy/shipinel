# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_fonts"
require_relative "../../lib/shipinel/layout"
require_relative "../../lib/shipinel/markdown/parser"
require_relative "../../lib/shipinel/scroll_spot"

# Headings at 16 ("Semana") and 77.2 ("Goal 1"): 16 + 43.2 (the level 1
# line) + 6 (half a gap after it) + 12 (a gap before the level 2 one).
class AnchorTest < Minitest::Test
  SOURCE = "# Semana\n\n## **Goal 1** — [Drata](https://x.test)\n\ntexto\n"

  def anchors
    page = Shipinel::Layout.new(fake_font_set, Shipinel::Styles.new(20.0), 400.0)
                           .arrange(Shipinel::Markdown::Parser.parse(SOURCE), [])
    page.anchors
  end

  def test_slugs_name_headings_like_links_to_them
    titles = ["Goal 1 — Drata monitoring tests", "Ação e Reunião!", " (P-DOS-224) "]

    assert_equal(["goal-1-drata-monitoring-tests", "ação-e-reunião", "p-dos-224"],
                 titles.map { |title| Shipinel::Anchor.slug_of(title) })
  end

  def test_layout_marks_each_heading_with_its_plain_title
    list = anchors

    assert_equal([["Semana", 16.0], ["Goal 1 — Drata", 77.2]], [0, 1].map do |position|
      [list.at(position).title, list.at(position).top.round(1)]
    end)
  end

  def test_the_section_is_the_last_heading_at_or_above_the_offset
    list = anchors

    assert_equal(["plan.md", "Semana", "Semana", "Goal 1 — Drata"],
                 [10.0, 16.0, 70.0, 300.0].map { |offset| list.title_above(offset, "plan.md") })
  end

  def test_spots_survive_a_heading_moving
    spot = Shipinel::ScrollSpot.at(100.0, anchors)
    moved = Shipinel::AnchorList.new
    moved.add(Shipinel::Anchor.new("Goal 1 — Drata", 500.0))

    assert_equal ["goal-1-drata", 22.8, 522.8], [spot.slug, spot.within.round(1), spot.offset_in(moved).round(1)]
  end

  def test_a_spot_whose_heading_is_gone_keeps_its_offset
    spot = Shipinel::ScrollSpot.new("removed", 5.0, 240.0)

    assert_in_delta 240.0, spot.offset_in(anchors)
  end

  def test_spots_above_every_heading_and_none
    top = Shipinel::ScrollSpot.at(4.0, anchors)

    assert_equal ["", 4.0, true, false], [top.slug, top.offset, top.aimed?, Shipinel::ScrollSpot.none.aimed?]
  end

  def test_zooming_scales_a_spot
    spot = Shipinel::ScrollSpot.new("goal-1", 10.0, 100.0).scaled(1.1)

    assert_equal [11.0, 110.0], [spot.within.round(1), spot.offset.round(1)]
  end
end
