# frozen_string_literal: true

# Ruby style, smells, complexity, duplication, file grades and unit tests.

require "json"
require "minitest/test_task"
require_relative "sources"

FLOG_METHOD_MAX = 20
FLAY_MASS_MAX = 25
RUBYCRITIC_GRADES = %w[A B].freeze
RUBYCRITIC_DIR = "build/rubycritic"

desc "Run every Ruby quality gate"
task ruby_checks: %i[rubocop reek flog flay rubycritic test]

desc "RuboCop with performance, rake, minitest and spinel cops"
task :rubocop do
  sh "rubocop"
end

desc "Reek with the default smells on app code"
task :reek do
  sh "reek", *Sources::APP_RUBY
end

desc "Flog: no method above #{FLOG_METHOD_MAX}; prints the total and 5 worst"
task :flog do
  require "flog"
  flog = Flog.new(all: true, methods: true)
  flog.flog(*Sources::APP_RUBY)
  worst = flog.totals.sort_by { |_name, score| -score }
  puts format("flog total: %<total>.1f", total: flog.total_score)
  worst.first(5).each { |name, score| puts format("  %<score>6.1f  %<name>s", score: score, name: name) }
  too_complex = worst.select { |_name, score| score > FLOG_METHOD_MAX }
  abort "flog: methods above #{FLOG_METHOD_MAX}: #{too_complex.map(&:first).join(', ')}" if too_complex.any?
end

desc "Flay: no duplication of mass #{FLAY_MASS_MAX} or more"
task :flay do
  require "flay"
  flay = Flay.new(mass: FLAY_MASS_MAX)
  flay.process(*Sources::APP_RUBY)
  flay.analyze
  puts "flay total: #{flay.total}"
  next if flay.masses.empty?

  flay.report
  abort "flay: duplication at mass #{FLAY_MASS_MAX} or more"
end

desc "RubyCritic report in #{RUBYCRITIC_DIR}; every file must grade #{RUBYCRITIC_GRADES.join(' or ')}"
task :rubycritic do
  sh "rubycritic", "--no-browser", "--format", "html", "--format", "json",
     "--path", RUBYCRITIC_DIR, *Sources::APP_RUBY
  modules = JSON.parse(File.read("#{RUBYCRITIC_DIR}/report.json")).fetch("analysed_modules")
  modules.each { |mod| puts "  #{mod.fetch('rating')}  #{mod.fetch('path')}" }
  low = modules.reject { |mod| RUBYCRITIC_GRADES.include?(mod.fetch("rating")) }
  abort "rubycritic: below B: #{low.map { |mod| mod.fetch('path') }.join(', ')}" if low.any?
end

# SimpleCov (test/unit/test_helper.rb) enforces 95% line coverage of lib/.
Minitest::TestTask.create(:test) do |t|
  t.libs = %w[. lib test/unit]
  t.test_globs = ["test/unit/**/*_test.rb"]
  # Coverage must start before minitest/autorun registers its exit hook.
  t.test_prelude = %(require "test/unit/test_helper")
  t.warning = true
end
