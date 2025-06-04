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

  def test_explain_option_syntax
    # Test explain option parsing for psql
    skip("PostgreSQL not available") unless system("command -v psql > /dev/null 2>&1")

    # Test 1: Standalone explain option
    test_file_1 = File.join(@temp_dir, "test_explain_standalone.md")
    md_content_standalone = <<~MARKDOWN
      ```psql explain
      SELECT 1 as simple_test;
      ```
    MARKDOWN
    File.write(test_file_1, md_content_standalone)
    MarkdownRun.run_code_blocks(test_file_1)

    file_content = File.read(test_file_1)
    assert file_content.include?("```RESULT"), "Result block should be created for explain query"
    # We can't test for specific explain output since it depends on PostgreSQL being configured

    # Test 2: Explicit explain=true option
    test_file_2 = File.join(@temp_dir, "test_explain_explicit.md")
    md_content_explicit = <<~MARKDOWN
      ```psql explain=true
      SELECT version();
      ```
    MARKDOWN
    File.write(test_file_2, md_content_explicit)
    MarkdownRun.run_code_blocks(test_file_2)

    file_content = File.read(test_file_2)
    assert file_content.include?("```RESULT"), "Result block should be created for explicit explain=true"

    # Test 3: Explicit explain=false should work normally
    test_file_3 = File.join(@temp_dir, "test_explain_false.md")
    md_content_false = <<~MARKDOWN
      ```psql explain=false
      SELECT 'normal query' as test;
      ```
    MARKDOWN
    File.write(test_file_3, md_content_false)
    MarkdownRun.run_code_blocks(test_file_3)

    file_content = File.read(test_file_3)
    assert file_content.include?("```RESULT"), "Result block should be created for normal query"
    assert file_content.include?("normal query"), "Output should contain the query result"
  end

  def test_result_option
    # Test 1: result=false should hide the result block but still execute code
    md_content_result_false = <<~MARKDOWN
      ```ruby result=false run
      puts "This result should be hidden"
      ```
    MARKDOWN
    test_file_1 = File.join(@temp_dir, "test_result_false.md")
    File.write(test_file_1, md_content_result_false)
    MarkdownRun.run_code_blocks(test_file_1)

    file_content = File.read(test_file_1)
    assert file_content.include?("```ruby result=false run"), "Original code block should be preserved"
    refute file_content.include?("```ruby RESULT"), "Result block should not be created when result=false"
    # The code executes but the result block is hidden, so we don't check for output

    # Test 2: result=true should show the result block (explicit true)
    md_content_result_true = <<~MARKDOWN
      ```ruby result=true run
      puts "This result should be visible"
      ```
    MARKDOWN
    test_file_2 = File.join(@temp_dir, "test_result_true.md")
    File.write(test_file_2, md_content_result_true)
    MarkdownRun.run_code_blocks(test_file_2)

    file_content = File.read(test_file_2)
    assert file_content.include?("```ruby result=true run"), "Original code block should be preserved"
    assert file_content.include?("```ruby RESULT"), "Result block should be created when result=true"
    assert file_content.include?("This result should be visible"), "Result output should appear"

    # Test 3: Default behavior (no result option) should show result block
    md_content_default = <<~MARKDOWN
      ```ruby run
      puts "Default behavior result"
      ```
    MARKDOWN
    test_file_3 = File.join(@temp_dir, "test_result_default.md")
    File.write(test_file_3, md_content_default)
    MarkdownRun.run_code_blocks(test_file_3)

    file_content = File.read(test_file_3)
    assert file_content.include?("```ruby run"), "Original code block should be preserved"
    assert file_content.include?("```ruby RESULT"), "Result block should be created by default"
    assert file_content.include?("Default behavior result"), "Result output should appear by default"

    # Test 4: Standalone result option should default to true
    md_content_standalone = <<~MARKDOWN
      ```ruby result run
      puts "Standalone result option"
      ```
    MARKDOWN
    test_file_4 = File.join(@temp_dir, "test_result_standalone.md")
    File.write(test_file_4, md_content_standalone)
    MarkdownRun.run_code_blocks(test_file_4)

    file_content = File.read(test_file_4)
    assert file_content.include?("```ruby result run"), "Original code block should be preserved"
    assert file_content.include?("```ruby RESULT"), "Result block should be created for standalone result"
    assert file_content.include?("Standalone result option"), "Result output should appear for standalone result"
  end

  def test_result_option_with_psql_explain
    skip("PostgreSQL not available") unless system("command -v psql > /dev/null 2>&1")

    # Test that psql explain default works
    md_content_psql_explain = <<~MARKDOWN
      ---
      markdown-run:
        psql:
          explain: true
      ---

      ```psql
      SELECT 'explain default test' as test;
      ```
    MARKDOWN
    test_file = File.join(@temp_dir, "test_psql_explain_default.md")
    File.write(test_file, md_content_psql_explain)
    MarkdownRun.run_code_blocks(test_file)

    file_content = File.read(test_file)
    assert file_content.include?("```RESULT"), "PSQL explain default should create result block"
    # The result should contain explain plan rather than simple query result
    # We can't test for specific explain output since it depends on PostgreSQL configuration
  end

  def test_frontmatter_defaults
    # Test global defaults - rerun only (without result=false to see the output)
    md_content_global_rerun = <<~MARKDOWN
      ---
      markdown-run:
        defaults:
          rerun: true
      ---

      ```ruby
      puts "Global rerun test: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      Global rerun test: 12345678
      ```
    MARKDOWN
    test_file_1 = File.join(@temp_dir, "test_global_rerun.md")
    File.write(test_file_1, md_content_global_rerun)
    MarkdownRun.run_code_blocks(test_file_1)

    file_content = File.read(test_file_1)
    # rerun: true should cause the old result to be replaced
    refute file_content.include?("Global rerun test: 12345678"), "Global rerun default should replace existing result"
    assert file_content.match?(/Global rerun test: \d+/), "Global rerun default should generate new result"

    # Test global defaults - result=false
    md_content_global_result_false = <<~MARKDOWN
      ---
      markdown-run:
        defaults:
          result: false
      ---

      ```ruby
      puts "Global result false test"
      ```
    MARKDOWN
    test_file_1b = File.join(@temp_dir, "test_global_result_false.md")
    File.write(test_file_1b, md_content_global_result_false)
    MarkdownRun.run_code_blocks(test_file_1b)

    file_content = File.read(test_file_1b)
    # result: false should hide the result block
    refute file_content.include?("```ruby RESULT"), "Global result=false default should hide result block"

    # Test language-specific defaults
    md_content_lang_defaults = <<~MARKDOWN
      ---
      markdown-run:
        ruby:
          rerun: true
        psql:
          explain: true
      ---

      ```ruby
      puts "Language-specific ruby test: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      Language-specific ruby test: 87654321
      ```
    MARKDOWN
    test_file_2 = File.join(@temp_dir, "test_lang_defaults.md")
    File.write(test_file_2, md_content_lang_defaults)
    MarkdownRun.run_code_blocks(test_file_2)

    file_content = File.read(test_file_2)
    # Language-specific rerun: true should replace existing result
    refute file_content.include?("Language-specific ruby test: 87654321"), "Language-specific rerun should replace existing result"
    assert file_content.match?(/Language-specific ruby test: \d+/), "Language-specific rerun should generate new result"

    # Test priority: explicit options > language defaults > global defaults
    md_content_priority = <<~MARKDOWN
      ---
      markdown-run:
        defaults:
          rerun: true
        ruby:
          rerun: false
      ---

      ```ruby rerun=true
      puts "Priority test: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      Priority test: 11111111
      ```
    MARKDOWN
    test_file_3 = File.join(@temp_dir, "test_priority.md")
    File.write(test_file_3, md_content_priority)
    MarkdownRun.run_code_blocks(test_file_3)

    file_content = File.read(test_file_3)
    # Explicit rerun=true should override language default rerun=false
    refute file_content.include?("Priority test: 11111111"), "Explicit option should override language default"
    assert file_content.match?(/Priority test: \d+/), "Explicit option should generate new result"

    # Test that language defaults override global defaults
    md_content_override = <<~MARKDOWN
      ---
      markdown-run:
        defaults:
          rerun: false
        ruby:
          rerun: true
      ---

      ```ruby
      puts "Override test: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      Override test: 22222222
      ```
    MARKDOWN
    test_file_4 = File.join(@temp_dir, "test_override.md")
    File.write(test_file_4, md_content_override)
    MarkdownRun.run_code_blocks(test_file_4)

    file_content = File.read(test_file_4)
    # Language-specific rerun: true should override global rerun: false
    refute file_content.include?("Override test: 22222222"), "Language default should override global default"
    assert file_content.match?(/Override test: \d+/), "Language default should generate new result"
  end

  def test_frontmatter_defaults_with_psql_explain
    skip("PostgreSQL not available") unless system("command -v psql > /dev/null 2>&1")

    # Test that psql explain default works
    md_content_psql_explain = <<~MARKDOWN
      ---
      markdown-run:
        psql:
          explain: true
      ---

      ```psql
      SELECT 'explain default test' as test;
      ```
    MARKDOWN
    test_file = File.join(@temp_dir, "test_psql_explain_default.md")
    File.write(test_file, md_content_psql_explain)
    MarkdownRun.run_code_blocks(test_file)

    file_content = File.read(test_file)
    assert file_content.include?("```RESULT"), "PSQL explain default should create result block"
    # The result should contain explain plan rather than simple query result
    # We can't test for specific explain output since it depends on PostgreSQL configuration
  end

  # --- Dalibo Link Replacement Tests ---

  def test_execution_decider_dalibo_detection
    # Test the ExecutionDecider's ability to detect Dalibo links
    require_relative "../lib/execution_decider"

    decider = ExecutionDecider.new(true, false, "psql", true, false, false)

    # Test Dalibo link detection
    assert decider.send(:is_dalibo_link?, "**Dalibo Visualization:** [View](https://explain.dalibo.com/plan/123)")
    refute decider.send(:is_dalibo_link?, "Some regular text")
    refute decider.send(:is_dalibo_link?, "```RESULT")
    refute decider.send(:is_dalibo_link?, "")
  end

  def test_execution_decider_auto_replace_logic
    # Test the auto-replacement logic for different scenarios
    require_relative "../lib/execution_decider"

    # explain=true, result=false should auto-replace
    decider1 = ExecutionDecider.new(true, false, "psql", true, false, false)
    assert decider1.send(:should_auto_replace_dalibo_link?), "Should auto-replace with explain=true, result=false"

    # explain=true, result=true should NOT auto-replace
    decider2 = ExecutionDecider.new(true, false, "psql", true, false, true)
    refute decider2.send(:should_auto_replace_dalibo_link?), "Should not auto-replace with explain=true, result=true"

    # explain=false should NOT auto-replace
    decider3 = ExecutionDecider.new(true, false, "psql", false, false, false)
    refute decider3.send(:should_auto_replace_dalibo_link?), "Should not auto-replace with explain=false"

    # flamegraph=true, result=false should auto-replace
    decider4 = ExecutionDecider.new(true, false, "psql", false, true, false)
    assert decider4.send(:should_auto_replace_dalibo_link?), "Should auto-replace with flamegraph=true, result=false"
  end

  def test_execution_decider_dalibo_immediate_handling
    # Test handling of immediate Dalibo links (no blank lines)
    require_relative "../lib/execution_decider"
    require_relative "../lib/enum_helper"

    lines = [
      "**Dalibo Visualization:** [View](https://explain.dalibo.com/plan/old-123)",
      "Some other content"
    ]
    file_enum = lines.to_enum

    # With auto-replace (explain result=false)
    decider = ExecutionDecider.new(true, false, "psql", true, false, false)
    result = decider.send(:handle_immediate_dalibo_link, file_enum)

    assert result[:execute], "Should execute with auto-replace"
    assert result[:consume_existing_dalibo], "Should consume existing Dalibo content"
  end

  def test_execution_decider_dalibo_with_blank_lines
    # Test handling of Dalibo links after blank lines
    require_relative "../lib/execution_decider"

    lines = [
      "",  # blank line
      "**Dalibo Visualization:** [View](https://explain.dalibo.com/plan/old-456)",
      "Some other content"
    ]
    file_enum = lines.to_enum

    # With auto-replace (explain result=false)
    decider = ExecutionDecider.new(true, false, "psql", true, false, false)
    result = decider.send(:handle_dalibo_after_blank_lines, file_enum, "", [])

    assert result[:execute], "Should execute with auto-replace after blank lines"
    assert result[:consume_existing_dalibo], "Should consume existing Dalibo content after blank lines"
  end

  def test_execution_decider_multiple_dalibo_consumption
    # Test that multiple consecutive Dalibo links are properly consumed
    require_relative "../lib/execution_decider"

    lines = [
      "**Dalibo Visualization:** [View](https://explain.dalibo.com/plan/link1)",
      "",
      "**Dalibo Visualization:** [View](https://explain.dalibo.com/plan/link2)",
      "**Dalibo Visualization:** [View](https://explain.dalibo.com/plan/link3)",
      "",
      "Some other content"
    ]
    file_enum = lines.to_enum
    consumed_lines = []

    decider = ExecutionDecider.new(true, false, "psql", true, false, false)
    decider.send(:consume_dalibo_links, file_enum, consumed_lines)

    assert_equal 5, consumed_lines.length, "Should consume all Dalibo links and blank lines"
    assert consumed_lines[0].include?("link1"), "Should consume first Dalibo link"
    assert consumed_lines[2].include?("link2"), "Should consume second Dalibo link"
    assert consumed_lines[3].include?("link3"), "Should consume third Dalibo link"
  end

  private

  # Helper method to create a simple file enum for testing
  def create_file_enum(lines)
    lines.to_enum
  end
end
