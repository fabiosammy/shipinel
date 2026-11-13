# frozen_string_literal: true

# Where another plan comes from: a Markdown file dropped on the window, or
# one picked in the desktop's file dialog after Ctrl+O (zenity on GNOME and
# most others, kdialog on KDE, whichever is installed). The dialog blocks
# the window while it is open, as a dialog does.

require_relative "document_view"
require_relative "input"
require_relative "screen"

module Shipinel
  # See the file comment.
  module PlanPicker
    # Example match: ".md" in "week.md"; also .markdown and .txt.
    MARKDOWN = /\.(md|markdown|txt)\z/i
    # The dialogs, tried in order. The title and filter are fixed text,
    # nothing from the file or the user.
    ZENITY = "zenity --file-selection --title='Open a plan' " \
             "--file-filter='Markdown | *.md *.markdown *.txt'"
    KDIALOG = "kdialog --title 'Open a plan' --getopenfilename ~ 'Markdown (*.md *.markdown *.txt)'"
    NO_DIALOG = "No file dialog: install zenity or kdialog, or drop a .md file on the window"

    # The plan this frame asks for: a Markdown file dropped on `screen`, or
    # the file picked after Ctrl+O; "" for none, the plan already open, a
    # cancelled dialog, or no dialog installed (then `document` says so in
    # its notice).
    #: (Input input, Screen screen, DocumentView document) -> String
    def self.wanted(input, screen, document)
      path = input.keys.commands.open? ? PlanPicker.picked(document) : PlanPicker.markdown(screen.dropped_file)
      path == document.path ? "" : path
    end

    # `path` when it is a Markdown file, else "".
    #: (String path) -> String
    def self.markdown(path)
      MARKDOWN.match?(path) ? path : ""
    end

    # The file chosen in the dialog; without one, the notice says what to
    # do instead.
    #: (DocumentView document) -> String
    def self.picked(document)
      return PlanPicker.pick unless PlanPicker.dialog.empty?

      document.notice(NO_DIALOG)
      ""
    end

    # The file chosen in the first dialog installed, "" when cancelled.
    #: () -> String
    def self.pick
      `#{PlanPicker.dialog}`.strip
    end

    # The first dialog command installed, or "".
    #: () -> String
    def self.dialog
      return ZENITY if PlanPicker.installed?("zenity")

      PlanPicker.installed?("kdialog") ? KDIALOG : ""
    end

    # Whether `tool` is on PATH.
    #: (String tool) -> bool
    def self.installed?(tool)
      system("sh", "-c", 'command -v "$1" >/dev/null', "shipinel-which", tool) ? true : false
    end
  end
end
