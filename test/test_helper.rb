require 'simplecov'

# Start SimpleCov before requiring any of your application code
SimpleCov.start do
  # Add filters to exclude certain files/directories from coverage
  add_filter '/test/'
  add_filter '/vendor/'

end

require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'

# Require your main library files
require_relative '../lib/markdown_run'
