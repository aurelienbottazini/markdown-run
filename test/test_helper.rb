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

# Common test functionality for markdown processing tests
module MarkdownTestHelper
  def setup
    @temp_dir = Dir.mktmpdir("markdown_exec_tests")
    @test_md_file_path = File.join(@temp_dir, "test.md")
  end

  def teardown
    FileUtils.remove_entry @temp_dir if @temp_dir && Dir.exist?(@temp_dir)
  end

  def create_md_file(content)
    File.write(@test_md_file_path, content)
    @test_md_file_path
  end

  def read_md_file
    File.read(@test_md_file_path)
  end

  def run_fixture_tests(fixture_prefix = nil)
    fixtures_dir = File.join(__dir__, "fixtures")

    # Discover all .input.md files and extract test case names
    pattern = fixture_prefix ? "#{fixture_prefix}*.input.md" : "*.input.md"
    input_files = Dir.glob(File.join(fixtures_dir, pattern))
    test_cases = input_files.map { |file| File.basename(file, ".input.md") }

    test_cases.each do |test_case|
      input_file = File.join(fixtures_dir, "#{test_case}.input.md")
      expected_file = File.join(fixtures_dir, "#{test_case}.expected.md")

      # Skip if expected file doesn't exist
      next unless File.exist?(expected_file)

      input_content = File.read(input_file)
      expected_content = File.read(expected_file).strip

      test_file = File.join(@temp_dir, "#{test_case}.md")
      File.write(test_file, input_content)
      MarkdownRun.run_code_blocks(test_file)

      assert_equal expected_content, File.read(test_file).strip, "Failed for test case: #{test_case}"
    end
  end
end
