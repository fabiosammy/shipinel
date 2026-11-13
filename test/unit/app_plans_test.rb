# frozen_string_literal: true

require_relative "app_test"

# Opening another plan while the window runs: dropped on it, or picked
# after Ctrl+O. Uses AppTest's fake screen.
class AppPlansTest < Minitest::Test
  FakeScreen = AppTest::FakeScreen

  def setup
    @dir = Dir.mktmpdir("shipinel")
    @path = File.join(@dir, "semana.md")
    File.write(@path, "# Semana\n- [ ] Reunião\n")
  end

  def teardown
    FileUtils.remove_entry(@dir)
    Shipinel::StopSignals.names.each { |name| Signal.trap(name, "DEFAULT") }
  end

  def run_app(screen)
    Shipinel::App.new(screen, Shipinel::Launch.new(@path, Shipinel::View.starting_at(20), PATHS, AppTest::CONFIG)).run
    screen
  end

  def other_plan
    other = File.join(@dir, "outra.md")
    File.write(other, "# Outra\n")
    other
  end

  # A Markdown file dropped after the first frame is drawn is shown on the
  # next one; where the first plan was is saved.
  def test_a_dropped_plan_opens
    screen = FakeScreen.new(frames: 3)
    screen.drop(other_plan, 1)
    run_app(screen)

    assert_equal [true, true], [screen.texts_on(1).include?("Outra"), Shipinel::StateFile.for(@path).read.include?("size=20")]
  end

  def test_a_dropped_file_that_is_not_markdown_is_ignored
    screen = FakeScreen.new(frames: 3)
    screen.drop(File.join(@dir, "photo.png"), 1)
    run_app(screen)

    refute_includes screen.texts_on(1), "Outra"
  end

  CTRL_O = Shipinel::CommandKeys::OPEN | Shipinel::KeyPress::Selecting::CONTROL

  # Ctrl+O opens the plan picked in the dialog.
  def test_ctrl_o_opens_the_picked_plan
    screen = FakeScreen.new(frames: 2)
    screen.keys = CTRL_O
    picked = other_plan
    Shipinel::PlanPicker.stub(:dialog, Shipinel::PlanPicker::ZENITY) do
      Shipinel::PlanPicker.stub(:pick, picked) { run_app(screen) }
    end

    assert_includes screen.texts_on(1), "Outra"
  end

  # Without zenity or kdialog the window says what to do.
  def test_ctrl_o_without_a_dialog_says_so
    screen = FakeScreen.new(frames: 2)
    screen.keys = CTRL_O
    Shipinel::PlanPicker.stub(:dialog, "") { run_app(screen) }

    assert_includes screen.texts_on(1).join, Shipinel::PlanPicker::NO_DIALOG
  end
end
