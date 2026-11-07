# frozen_string_literal: true

# Opens a clicked link with the desktop's default handler (xdg-open). A URL
# with a scheme (https:, mailto:) opens as it is; a relative link is a file
# next to the plan, so it is resolved against the plan's directory. The
# handler runs in the background, so the window never waits for it.

module Shipinel
  # See the file comment.
  class LinkOpener
    # The desktop's "open this" command.
    XDG_OPEN = "xdg-open"
    # Example match: "https:" in "https://linear.app/x"
    SCHEME = /\A[a-z][a-z0-9+.-]*:/i
    # The launcher and target are the shell's $1 and $2, never part of the
    # shell text, so a URL cannot run commands. Output goes nowhere:
    # browsers are chatty.
    SCRIPT = '"$1" "$2" >/dev/null 2>&1 &'

    # @rbs @base_dir: String
    # @rbs @launcher: String

    # `launcher` is XDG_OPEN, or a stand-in in tests.
    #: (String base_dir, String launcher) -> void
    def initialize(base_dir, launcher)
      @base_dir = base_dir
      @launcher = launcher
    end

    # "" when started (or nothing to open), else why not.
    #: (String url) -> String
    def open(url)
      target = target_for(url)
      return "" if target.empty?

      system("sh", "-c", SCRIPT, "shipinel-open", @launcher, target) ? "" : "Could not open #{url}"
    end

    # What xdg-open is given; "" for a link to a place in the same file.
    #: (String url) -> String
    def target_for(url)
      return url if SCHEME.match?(url)

      path = url.split("#").first.to_s
      path.empty? ? "" : File.expand_path(path, @base_dir)
    end
  end
end
