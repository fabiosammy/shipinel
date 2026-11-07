# frozen_string_literal: true

# spin snapshot test: toggling and atomic saves compiled by Spinel must leave
# the same bytes on disk, and report the same outcomes, as under CRuby.
# Works in build/toggler-snapshot, recreated on every run.

require_relative "../lib/shipinel/task_toggler"

# Runs each toggle scenario against a fresh file and prints the outcome.
class TogglerSnapshot
  DIR = "build/toggler-snapshot"
  PLAN = "#{DIR}/semana.md".freeze
  SOURCE = "# Semana\r\n- [ ] Reunião\r\n  * [X] Pauta\r\n```\r\n- [ ] código\r\n```\r\n- [x] fim"

  #: () -> void
  def run
    prepare
    toggler = Shipinel::TaskToggler.new(Shipinel::DocumentFile.new(PLAN))
    toggles(toggler)
    refusals(toggler)
    show("uncheck last line", toggler.toggle(Shipinel::TaskClick.new(6, true)))
    puts "mode #{File.stat(PLAN).mode & 0o777}"
    nil
  end

  #: (Shipinel::TaskToggler toggler) -> void
  def toggles(toggler)
    show("check line 1", toggler.toggle(Shipinel::TaskClick.new(1, false)))
    show("uncheck line 2", toggler.toggle(Shipinel::TaskClick.new(2, true)))
  end

  #: (Shipinel::TaskToggler toggler) -> void
  def refusals(toggler)
    show("line 1 is no longer unchecked", toggler.toggle(Shipinel::TaskClick.new(1, false)))
    show("fenced line 4", toggler.toggle(Shipinel::TaskClick.new(4, false)))
    show("heading line 0", toggler.toggle(Shipinel::TaskClick.new(0, false)))
    show("past the end", toggler.toggle(Shipinel::TaskClick.new(99, false)))
  end

  #: () -> void
  def prepare
    make_dir("build")
    make_dir(DIR)
    File.write(PLAN, SOURCE)
    File.chmod(0o640, PLAN)
    nil
  end

  #: (String path) -> void
  def make_dir(path)
    Dir.mkdir(path)
    nil
  rescue Errno::EEXIST
    nil
  end

  #: (String label, Shipinel::ToggleResult result) -> void
  def show(label, result)
    puts "#{label}: #{result.status} [#{result.problem}]"
    puts File.read(PLAN).inspect
  end
end

TogglerSnapshot.new.run
missing = Shipinel::TaskToggler.new(Shipinel::DocumentFile.new("build/toggler-snapshot/missing.md"))
puts missing.toggle(Shipinel::TaskClick.new(0, false)).problem
