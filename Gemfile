# frozen_string_literal: true

source "https://rubygems.org"

# Development tooling only: the shipped binary is compiled by Spinel and links
# no gems. Everything here runs under CRuby for `rake check`.
group :development, :test do
  gem "flay", "~> 2.13"
  gem "flog", "~> 4.8"
  gem "minitest", "~> 5.25"
  # rubycritic (through virtus) needs ostruct, which leaves the default gems in Ruby 4.0.
  gem "ostruct", "~> 0.6"
  gem "rake", "~> 13.2"
  gem "rbs-inline", "~> 0.11", require: false
  gem "reek", "~> 6.4"
  gem "rubocop", "~> 1.84"
  gem "rubocop-minitest", "~> 0.38"
  gem "rubocop-performance", "~> 1.25"
  gem "rubocop-rake", "~> 0.7"
  gem "rubocop_spinel", "~> 0.2.0"
  gem "rubycritic", "~> 4.9"
  gem "simplecov", "~> 0.22"
  gem "steep", "~> 1.10"
end
