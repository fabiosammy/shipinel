# frozen_string_literal: true

# The file lists every rake task works on, kept in one place.
module Sources
  # Production Ruby: what metrics, smells and complexity are measured on.
  APP_RUBY = FileList["bin/*.rb", "lib/**/*.rb"].to_a.freeze
  # Programs Spinel compiles: the app and the spin snapshot tests.
  SPINEL_PROGRAMS = FileList["bin/shipinel.rb", "test/*.rb"].to_a.freeze
  C_SOURCES = FileList["ext/*.c"].to_a.freeze
  C_FILES = FileList["ext/*.c", "ext/*.h"].to_a.freeze
end
