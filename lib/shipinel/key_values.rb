# frozen_string_literal: true

# The text format of Shipinel's own files (the config and the saved state):
# one key=value per line. Blank lines, lines starting with "#", and lines
# without "=" are skipped; the last value given for a key wins.

module Shipinel
  # See the file comment.
  class KeyValues
    # @rbs @values: Hash[String, String]

    #: (String text) -> void
    def initialize(text)
      @values = {}
      text.each_line { |line| take(line.strip) }
    end

    # "size=22" -> "size". (Not String#partition: that name pulls in
    # Spinel's widening Enumerable#partition, docs/spinel-notes.md.)
    #: (String line) -> String
    def self.key_of(line)
      line.split("=", 2).first.to_s.strip
    end

    # "size=22" -> "22".
    #: (String line) -> String
    def self.value_of(line)
      line.split("=", 2).last.to_s.strip
    end

    # Not blank, not a comment, and has "=".
    #: (String line) -> bool
    def self.setting?(line)
      line.include?("=") && !line.start_with?("#")
    end

    # "" when the key is not there.
    #: (String key) -> String
    def [](key)
      @values.fetch(key, "")
    end

    # The keys given, in the order first seen.
    #: () -> Array[String]
    def keys
      @values.keys
    end

    private

    #: (String line) -> void
    def take(line)
      @values[KeyValues.key_of(line)] = KeyValues.value_of(line) if KeyValues.setting?(line)
      nil
    end
  end
end
