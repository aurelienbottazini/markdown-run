require 'simplecov'

# Start SimpleCov before requiring any of your application code
SimpleCov.start do
  # Add filters to exclude certain files/directories from coverage
  add_filter '/test/'
  add_filter '/vendor/'

  # Set minimum coverage threshold (optional)
  minimum_coverage 75

  # Track branches as well as lines (more comprehensive coverage)
  enable_coverage :branch

  # Custom coverage groups (optional)
  add_group "Core Library", "lib"
  add_group "Executors", "lib/*_executor.rb"
  add_group "Processors", "lib/*_processor.rb"
end

require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'

# Require your main library files
require_relative '../lib/markdown_run'