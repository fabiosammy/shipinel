# frozen_string_literal: true

# Reads the week plan, and replaces it atomically: the new content goes to a
# temp file in the same directory, which is then renamed over the original,
# so an editor (or a crash) never sees half a file.

module Shipinel
  # What one read of the file found: its content, or why it could not be
  # read. Comparing two snapshots is how a change on disk is noticed.
  class Snapshot
    attr_reader :content #: String
    attr_reader :problem #: String

    #: (String content, String problem) -> void
    def initialize(content, problem)
      @content = content
      @problem = problem
    end

    #: () -> bool
    def readable?
      @problem.empty?
    end

    #: (Snapshot other) -> bool
    def same_as?(other)
      @content == other.content && @problem == other.problem
    end
  end

  # The hidden file a save is written to before it is renamed over the
  # target. Same directory, so the rename never crosses file systems.
  class TempFile
    # Owner, group and other permission bits, plus setuid/setgid/sticky.
    PERMISSION_BITS = 0o7777

    # @rbs @target: String
    # @rbs @path: String

    #: (String target) -> void
    def initialize(target)
      @target = target
      @path = File.join(File.dirname(target), ".#{File.basename(target)}.shipinel-tmp")
    end

    # Writes the content and renames it over the target. On any failure the
    # temp file is removed and the error raised again; the target is untouched.
    #: (String content) -> void
    def replace_target(content)
      write_with_target_permissions(content)
      File.rename(@path, @target)
      nil
    rescue SystemCallError
      discard
      raise
    end

    private

    # So that a save does not change who may read or write the plan.
    #: (String content) -> void
    def write_with_target_permissions(content)
      File.write(@path, content)
      File.chmod(File.stat(@target).mode & PERMISSION_BITS, @path)
      nil
    end

    # Unlinking and ignoring "not there" is atomic, unlike asking first.
    # (Spinel's FileUtils.rm_f does not compile without widening.)
    #: () -> void
    def discard
      File.unlink(@path)
      nil
    rescue Errno::ENOENT
      nil
    end
  end

  # See the file comment.
  class DocumentFile
    attr_reader :path #: String

    #: (String path) -> void
    def initialize(path)
      @path = path
    end

    #: () -> Snapshot
    def read
      Snapshot.new(File.read(@path), "")
    rescue Errno::ENOENT
      Snapshot.new("", "#{@path} does not exist. Waiting for it to appear.")
    rescue SystemCallError => error
      Snapshot.new("", "Cannot read #{@path}: #{error.message}")
    end

    # Returns "" when saved, or why not; the original file is then untouched.
    # A symlinked plan is written through the link, which stays a link.
    #: (String content) -> String
    def write(content)
      TempFile.new(File.realpath(@path)).replace_target(content)
      ""
    rescue SystemCallError => error
      "Cannot save #{@path}: #{error.message}"
    end
  end
end
