# frozen_string_literal: true

# Lays a block quote out on the Flow: its text indented, italic and dimmed
# (Styles#quote), with a bar down its left side as tall as the text.

require_relative "draw_list"
require_relative "geometry"
require_relative "theme"

module Shipinel
  # See the file comment.
  class QuoteLayout
    BAR_WIDTH = 3.0

    # @rbs @flow: Flow

    #: (Flow flow) -> void
    def initialize(flow)
      @flow = flow
    end

    #: (String text) -> void
    def place(text)
      top = @flow.top
      styles = @flow.styles
      @flow.text(text, styles.size, styles.quote)
      add_bar(top)
    end

    private

    # From `top` down to where the quote's text ended.
    #: (Float top) -> void
    def add_bar(top)
      @flow.add(Box.new(Rect.new(Theme::Spacing::MARGIN, top, BAR_WIDTH, @flow.top - top), Theme::Surface::RULE))
    end
  end
end
