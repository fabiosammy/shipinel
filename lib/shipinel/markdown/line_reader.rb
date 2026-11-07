# frozen_string_literal: true

# Recognises one source line as a heading, rule, task, bullet or fence. The
# task pattern is shared with TaskToggler, so "what the parser shows as a
# task" and "what a click may toggle" can never disagree.

require_relative "block"
require_relative "list_nesting"
require_relative "source_line"

module Shipinel
  module Markdown
    # See the file comment. Which fence is open, and paragraphs, are state
    # that Parser keeps.
    module LineReader
      # Example match: "## Segunda-feira ##" (hashes "##", text "Segunda-feira";
      # closing hashes are optional and dropped)
      HEADING = /\A {0,3}(?<hashes>\#{1,6})(?:[ \t]+(?<text>.*?))?(?:[ \t]+\#+)?[ \t]*\z/
      # Example match: "---" or "* * *"
      RULE = /\A {0,3}(?:(?:-[ \t]*){3,}|(?:\*[ \t]*){3,}|(?:_[ \t]*){3,})\z/
      # Example match: "  - [x] Ligar para a Ana" (indent "  ", mark "x")
      TASK = /\A(?<indent>[ \t]*)[-*+][ \t]+\[(?<mark>[ xX])\](?:[ \t]+(?<text>.*))?\z/
      # Example match: "* comprar pão" (indent "", text "comprar pão")
      BULLET = /\A(?<indent>[ \t]*)[-*+][ \t]+(?<text>.*)\z/
      # Example match: "```ruby" (marker "```", info "ruby")
      FENCE = /\A {0,3}(?<marker>`{3,}|~{3,})(?<info>.*)\z/

      # The fence characters ("```" or "~~~~"), or "" when the line opens none.
      #: (SourceLine line) -> String
      def self.fence_marker(line)
        match = FENCE.match(line.text)
        match ? match[:marker].to_s : ""
      end

      # A fence closes with the same character, at least as many times, and
      # nothing after it: "````" closes "```", "~~~" does not.
      #: (SourceLine line, String open_marker) -> bool
      def self.closes_fence?(line, open_marker)
        match = FENCE.match(line.text)
        return false unless match

        match[:marker].to_s.start_with?(open_marker) && match[:info].to_s.strip.empty?
      end

      #: (SourceLine line) -> Block?
      def self.heading(line)
        match = HEADING.match(line.text)
        return nil unless match

        Heading.new(line.line_index, match[:hashes].to_s.size, match[:text].to_s)
      end

      #: (SourceLine line) -> Block?
      def self.rule(line)
        RULE.match?(line.text) ? Rule.new(line.line_index) : nil
      end

      # Checked before bullet: every task line is also a bullet line.
      #: (SourceLine line, ListNesting nesting) -> Block?
      def self.task(line, nesting)
        match = TASK.match(line.text)
        return nil unless match

        depth = nesting.depth_for(match[:indent].to_s)
        Task.new(line.line_index, depth, match[:text].to_s, match[:mark] != " ")
      end

      #: (SourceLine line, ListNesting nesting) -> Block?
      def self.bullet(line, nesting)
        match = BULLET.match(line.text)
        return nil unless match

        Bullet.new(line.line_index, nesting.depth_for(match[:indent].to_s), match[:text].to_s)
      end
    end
  end
end
