require "minitest/autorun"
require "fileutils"
require "tmpdir"

# Require the markdown run module
require_relative "../lib/markdown_run"

# --- Minitest Test Class Definition ---
class TestMarkdownRun < Minitest::Test
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
    assert MarkdownRun.run_code_blocks(@test_md_file_path), "Processing empty file should succeed"
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
    MarkdownRun.run_code_blocks(@test_md_file_path)

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
    MarkdownRun.run_code_blocks(@test_md_file_path)

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
    MarkdownRun.run_code_blocks(@test_md_file_path)

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
    MarkdownRun.run_code_blocks(@test_md_file_path)

    assert_equal original_content.strip, read_md_file.strip, "Should not execute if ```ruby RESULT block exists"
  end

  def test_frontmatter_alias_functionality
    skip "Skipping test_frontmatter_alias_functionality on GitHub CI" if ENV['CI']

    md_content = <<~MARKDOWN
      ---
      markdown-run:
        alias:
          - sql: psql
      ---

      # Test Document

      ```sql
      SELECT 'aliased to psql' as test;
      ```
    MARKDOWN
    create_md_file(md_content)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    file_content = read_md_file
    assert file_content.include?("```sql\nSELECT 'aliased to psql' as test;"), "Original SQL code should be present"
    assert file_content.include?("```RESULT\n"), "RESULT block should be created for aliased language"
    assert file_content.include?("aliased to psql"), "Output should contain the expected result"
  end

  def test_rerun_functionality
    # Test 1: Default behavior (no rerun option) should skip existing result
    md_content_with_result = <<~MARKDOWN
      ```ruby
      puts "Should not change: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      Should not change: 999999999
      ```
    MARKDOWN
    create_md_file(md_content_with_result)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    file_content = read_md_file
    assert file_content.include?("Should not change: 999999999"), "Default behavior should preserve existing result"
    refute file_content.match?(/Should not change: (?!999999999)\d+/), "Default behavior should not generate new timestamp"

    # Test 2: rerun=false should skip existing result
    md_content_rerun_false = <<~MARKDOWN
      ```ruby rerun=false
      puts "Should not change either: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      Should not change either: 888888888
      ```
    MARKDOWN
    create_md_file(md_content_rerun_false)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    file_content = read_md_file
    assert file_content.include?("Should not change either: 888888888"), "rerun=false should preserve existing result"
    refute file_content.match?(/Should not change either: (?!888888888)\d+/), "rerun=false should not generate new timestamp"

    # Test 3: rerun=true should replace existing result
    md_content_rerun_true = <<~MARKDOWN
      ```ruby rerun=true
      puts "Should change: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      Should change: 777777777
      ```
    MARKDOWN
    create_md_file(md_content_rerun_true)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    file_content = read_md_file
    refute file_content.include?("Should change: 777777777"), "rerun=true should replace existing result"
    assert file_content.match?(/Should change: \d+/), "rerun=true should generate new result with actual timestamp"

    # Test 4: rerun=true with blank line before result block
    md_content_rerun_true_blank = <<~MARKDOWN
      ```ruby rerun=true
      puts "Should also change: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      Should also change: 666666666
      ```
    MARKDOWN
    create_md_file(md_content_rerun_true_blank)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    file_content = read_md_file
    refute file_content.include?("Should also change: 666666666"), "rerun=true with blank line should replace existing result"
    assert file_content.match?(/Should also change: \d+/), "rerun=true with blank line should generate new result"
  end

  def test_run_functionality
    # Test 1: Default behavior (run=true implicit) should execute new code block
    md_content_default = <<~MARKDOWN
      ```ruby
      puts "Should execute by default"
      ```
    MARKDOWN
    create_md_file(md_content_default)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    file_content = read_md_file
    assert file_content.include?("```ruby RESULT"), "Default behavior should create result block"
    assert file_content.include?("Should execute by default"), "Default behavior should execute and show output"

    # Test 2: run=true explicit should execute new code block
    md_content_run_true = <<~MARKDOWN
      ```ruby run=true
      puts "Should execute with run=true"
      ```
    MARKDOWN
    create_md_file(md_content_run_true)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    file_content = read_md_file
    assert file_content.include?("```ruby RESULT"), "run=true should create result block"
    assert file_content.include?("Should execute with run=true"), "run=true should execute and show output"

    # Test 3: run=false should not execute at all (no result block created)
    md_content_run_false = <<~MARKDOWN
      ```ruby run=false
      puts "Should not execute"
      puts "No result block should be created"
      ```
    MARKDOWN
    create_md_file(md_content_run_false)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    file_content = read_md_file
    refute file_content.include?("```ruby RESULT"), "run=false should not create result block"
    refute file_content.match?(/puts "Should not execute"\n# >>/), "run=false should not execute code (no # >> output)"
    assert file_content.include?("puts \"Should not execute\""), "run=false should preserve original code block"

    # Test 4: run=false with existing result block should skip execution but preserve result
    md_content_run_false_with_result = <<~MARKDOWN
      ```ruby run=false
      puts "Should not execute"
      ```

      ```ruby RESULT
      Old result that should be preserved
      ```
    MARKDOWN
    create_md_file(md_content_run_false_with_result)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    file_content = read_md_file
    assert file_content.include?("Old result that should be preserved"), "run=false should preserve existing result"
    refute file_content.match?(/puts "Should not execute"\n# >>/), "run=false should not create new execution output"

    # Test 5: Combined options - run=false with rerun=true should still not execute
    md_content_combined = <<~MARKDOWN
      ```ruby run=false rerun=true
      puts "Should not execute despite rerun=true"
      ```

      ```ruby RESULT
      Existing result
      ```
    MARKDOWN
    create_md_file(md_content_combined)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    file_content = read_md_file
    assert file_content.include?("Existing result"), "run=false should override rerun=true"
    refute file_content.match?(/puts "Should not execute despite rerun=true"\n# >>/), "run=false should prevent execution even with rerun=true"

    # Test 6: Combined options - run=true with rerun=false should execute if no result exists
    md_content_run_true_rerun_false = <<~MARKDOWN
      ```ruby run=true rerun=false
      puts "Should execute because no result exists"
      ```
    MARKDOWN
    create_md_file(md_content_run_true_rerun_false)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    file_content = read_md_file
    assert file_content.include?("```ruby RESULT"), "run=true rerun=false should execute when no result exists"
    assert file_content.include?("Should execute because no result exists"), "run=true rerun=false should show output when no result exists"
  end

  def test_mermaid_block_execution
    skip "Skipping test_mermaid_block_execution if mmdc not available" unless system("command -v mmdc > /dev/null 2>&1")

    md_content = <<~MARKDOWN
      ```mermaid
      graph TD
          A[Start] --> B[Process]
          B --> C[End]
      ```
    MARKDOWN
    create_md_file(md_content)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    file_content = read_md_file
    assert file_content.include?("```mermaid"), "Original mermaid code should be present"
    assert file_content.match?(/!\[Mermaid Diagram\]\(.+\.svg\)/), "Mermaid should generate SVG image tag"
    refute file_content.include?("```RESULT"), "Mermaid should not create a RESULT block"
  end

  def test_standalone_option_syntax
    # Test 1: standalone rerun should work like rerun=true
    md_content_standalone_rerun = <<~MARKDOWN
      ```ruby rerun
      puts "Standalone rerun test: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      Standalone rerun test: 999999999
      ```
    MARKDOWN
    test_file_1 = File.join(@temp_dir, "test1.md")
    File.write(test_file_1, md_content_standalone_rerun)
    MarkdownRun.run_code_blocks(test_file_1)

    file_content = File.read(test_file_1)
    assert file_content.include?("```ruby RESULT"), "Standalone rerun should create result block"
    refute file_content.include?("Standalone rerun test: 999999999"), "Standalone rerun should replace existing result"
    assert file_content.match?(/Standalone rerun test: \d+/), "Standalone rerun should generate new result"

    # Test 2: standalone run should work like run=true (default behavior)
    md_content_standalone_run = <<~MARKDOWN
      ```ruby run
      puts "Standalone run test"
      ```
    MARKDOWN
    test_file_2 = File.join(@temp_dir, "test2.md")
    File.write(test_file_2, md_content_standalone_run)
    MarkdownRun.run_code_blocks(test_file_2)

    file_content = File.read(test_file_2)
    assert file_content.include?("```ruby RESULT"), "Standalone run should create result block"
    assert file_content.include?("Standalone run test"), "Standalone run should execute and show output"

    # Test 3: explicit option should override standalone option
    md_content_mixed_options = <<~MARKDOWN
      ```ruby rerun run=false
      puts "Execution test: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      Existing result to preserve
      ```
    MARKDOWN
    test_file_3 = File.join(@temp_dir, "test3.md")
    File.write(test_file_3, md_content_mixed_options)
    MarkdownRun.run_code_blocks(test_file_3)

    file_content = File.read(test_file_3)
    assert file_content.include?("Existing result to preserve"), "run=false should override standalone rerun"
    # Since run=false, the code should not execute and the result should remain unchanged
    refute file_content.match?(/Execution test: \d+/), "run=false should prevent execution and result generation"
  end
end
