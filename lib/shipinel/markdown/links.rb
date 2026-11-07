# frozen_string_literal: true

# Recognises a link at the start of a piece of text: a Markdown link
# [text](url), an angle-bracket autolink <https://...>, or a bare http(s)
# URL. Inline calls it where a link could start.

module Shipinel
  module Markdown
    # A link found in text: what to show, where it goes, and how many
    # characters of the source it took.
    class LinkMatch
      attr_reader :text #: String
      attr_reader :url #: String
      attr_reader :length #: Integer

      #: (String text, String url, Integer length) -> void
      def initialize(text, url, length)
        @text = text
        @url = url
        @length = length
      end
    end

    # See the file comment.
    module Links
      # Characters a link can start with: "[" (Markdown), "<" (autolink),
      # "h" (a bare URL).
      STARTS = "[<h"
      # Example match: "[DOS-558](https://linear.app/x)" (text "DOS-558",
      # url "https://linear.app/x")
      MARKDOWN = /\A\[(?<text>[^\]]+)\]\((?<url>[^)\s]+)\)/
      # Example match: "<https://example.com/a>" (url "https://example.com/a")
      ANGLE = %r{\A<(?<url>https?://[^\s>]+)>}
      # Example match: "https://example.com/a" in "see https://example.com/a."
      # (punctuation that ends a sentence is not part of the URL)
      BARE = %r{\Ahttps?://[^\s<>]*[^\s<>.,;:!?)\]'"]}

      #: (String text) -> LinkMatch?
      def self.at(text)
        markdown(text) || angle(text) || bare(text)
      end

      #: (String text) -> LinkMatch?
      def self.markdown(text)
        match = MARKDOWN.match(text)
        match ? LinkMatch.new(match[:text].to_s, match[:url].to_s, match[0].to_s.size) : nil
      end

      #: (String text) -> LinkMatch?
      def self.angle(text)
        match = ANGLE.match(text)
        return nil unless match

        url = match[:url].to_s
        LinkMatch.new(url, url, match[0].to_s.size)
      end

      #: (String text) -> LinkMatch?
      def self.bare(text)
        url = BARE.match(text).to_s
        url.empty? ? nil : LinkMatch.new(url, url, url.size)
      end
    end
  end
end
