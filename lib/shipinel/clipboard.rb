# frozen_string_literal: true

# The system clipboard, through the C shim (GLFW keeps a copy and serves
# other programs while the window runs): what Ctrl+C copies.

module Shipinel
  # See the file comment.
  module Clipboard
    #: (String text) -> void
    def self.copy(text)
      UI.ui_set_clipboard(text)
    end
  end
end
