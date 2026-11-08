# frozen_string_literal: true

# Places one list item on the Flow: its checkbox or marker ("•", "2."),
# then its text, indented by nesting depth. A task's text is quieter when
# it is done or waiting on something.

require_relative "task_toggler"
require_relative "theme"

module Shipinel
  # See the file comment.
  class ListLayout
    # @rbs @flow: Flow
    # @rbs @indent: Float

    #: (Flow flow, Integer depth) -> void
    def initialize(flow, depth)
      @flow = flow
      @indent = depth * flow.styles.size * Theme::Spacing::INDENT
    end

    # The checkbox carries the click a user would make on it: the task's
    # line and the state the file has now.
    #: (String text, Integer line_index, bool checked) -> void
    def task(text, line_index, checked)
      styles = @flow.styles
      @flow.checkbox(@indent, TaskClick.new(line_index, checked))
      @flow.text(text, text_indent, checked ? styles.done : styles.open_task(text))
    end

    # The marker ends just before the text starts.
    #: (String text, String marker) -> void
    def bullet(text, marker)
      style = @flow.styles.body
      @flow.marker(marker, text_indent, style)
      @flow.text(text, text_indent, style)
    end

    private

    # Where the item's text starts: after its checkbox or marker.
    #: () -> Float
    def text_indent
      @indent + (@flow.styles.size * Theme::Spacing::MARKER)
    end
  end
end
