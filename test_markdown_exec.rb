require "bundler/inline"
gemfile(true) do
  source "https://rubygems.org"
  gem "minitest", "5.25.5" # Specify the required version
  gem "rcodetools"
end

require "minitest/test"
require "minitest/autorun"
require "fileutils"
require "tmpdir"

# --- Minitest Test Class Definition ---
class TestMarkdownExec < Minitest::Test
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

  def test_script_runs_without_error_on_empty_file
    create_md_file("")
    assert process_markdown_file_main(@test_md_file_path), "Processing empty file should succeed"
    assert_equal "", read_md_file.strip, "Empty file should remain empty after processing"
  end

  def test_psql_block_execution
    skip "Skipping test_psql_block_execution on GitHub CI" if ENV['CI']

    md_content = <<~MARKDOWN
      ```psql
      SELECT 'hello psql test';
      ```
    MARKDOWN
    create_md_file(md_content)
    process_markdown_file_main(@test_md_file_path)

    expected_output = <<~MARKDOWN.strip
      ```psql
      SELECT 'hello psql test';
      ```

      ```RESULT
      hello psql test
      ```
    MARKDOWN
    assert_equal expected_output, read_md_file.strip
  end

  def test_ruby_block_execution_and_result_generation
    md_content = <<~MARKDOWN
      ```ruby
      puts "Hello from Ruby"
      p 1 + 2
      ```
    MARKDOWN
    create_md_file(md_content)
    process_markdown_file_main(@test_md_file_path)

    file_content = read_md_file
    assert file_content.include?("```ruby\nputs \"Hello from Ruby\""), "Original Ruby code should be present"
    assert file_content.include?("```ruby RESULT\n"), "Ruby RESULT block should be created"
    assert file_content.include?("3"), "Output from p 1 + 2 should be in the result"
  end

  def test_skip_execution_if_result_block_exists
    original_content = <<~MARKDOWN
      ```psql
      SELECT 'this should not run';
      ```

      ```RESULT
      pre-existing result
      ```
    MARKDOWN
    create_md_file(original_content)
    process_markdown_file_main(@test_md_file_path)

    assert_equal original_content.strip, read_md_file.strip, "Should not execute if RESULT block exists"
  end

  def test_skip_execution_if_ruby_result_block_exists
    original_content = <<~MARKDOWN
      ```ruby
      puts "this should not run either"
      ```

      ```ruby RESULT
      this is a pre-existing ruby result
      ```
    MARKDOWN
    create_md_file(original_content)
    process_markdown_file_main(@test_md_file_path)

    assert_equal original_content.strip, read_md_file.strip, "Should not execute if ```ruby RESULT block exists"
  end
end
