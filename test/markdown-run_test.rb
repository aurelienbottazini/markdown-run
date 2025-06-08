require_relative 'test_helper'

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



  def test_ruby_block_execution_and_result_generation
    md_content = <<~MARKDOWN
      ```ruby
      puts "Hello from Ruby"
      p 1 + 2
      ```
    MARKDOWN
    create_md_file(md_content)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    expected_output = <<~MARKDOWN.strip
      ```ruby
      puts "Hello from Ruby"
      p 1 + 2
      ```

      ```ruby RESULT
      puts "Hello from Ruby"
      p 1 + 2
      # >> Hello from Ruby
      # >> 3
      ```
    MARKDOWN
    assert_equal expected_output, read_md_file.strip
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

    expected_output = <<~MARKDOWN.strip
      ```ruby
      puts "Should not change: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      Should not change: 999999999
      ```
    MARKDOWN
    assert_equal expected_output, read_md_file.strip

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

    expected_output = <<~MARKDOWN.strip
      ```ruby rerun=false
      puts "Should not change either: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      Should not change either: 888888888
      ```
    MARKDOWN
    assert_equal expected_output, read_md_file.strip

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
    # Extract the actual timestamp from the output and build expected output
    timestamp_match = file_content.match(/Should change: (\d+)/)
    assert timestamp_match, "Should find generated timestamp in output"
    actual_timestamp = timestamp_match[1]

    expected_output = <<~MARKDOWN.strip
      ```ruby rerun=true
      puts "Should change: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      puts "Should change: \#{Time.now.to_i}"
      # >> Should change: #{actual_timestamp}
      ```
    MARKDOWN
    assert_equal expected_output, file_content.strip

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
    # Extract the actual timestamp from the output and build expected output
    timestamp_match = file_content.match(/Should also change: (\d+)/)
    assert timestamp_match, "Should find generated timestamp in output"
    actual_timestamp = timestamp_match[1]

    expected_output = <<~MARKDOWN.strip
      ```ruby rerun=true
      puts "Should also change: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      puts "Should also change: \#{Time.now.to_i}"
      # >> Should also change: #{actual_timestamp}
      ```
    MARKDOWN
    assert_equal expected_output, file_content.strip
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

    expected_output = <<~MARKDOWN.strip
      ```ruby
      puts "Should execute by default"
      ```

      ```ruby RESULT
      puts "Should execute by default"
      # >> Should execute by default
      ```
    MARKDOWN
    assert_equal expected_output, read_md_file.strip

    # Test 2: run=true explicit should execute new code block
    md_content_run_true = <<~MARKDOWN
      ```ruby run=true
      puts "Should execute with run=true"
      ```
    MARKDOWN
    create_md_file(md_content_run_true)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    expected_output = <<~MARKDOWN.strip
      ```ruby run=true
      puts "Should execute with run=true"
      ```

      ```ruby RESULT
      puts "Should execute with run=true"
      # >> Should execute with run=true
      ```
    MARKDOWN
    assert_equal expected_output, read_md_file.strip

    # Test 3: run=false should not execute at all (no result block created)
    md_content_run_false = <<~MARKDOWN
      ```ruby run=false
      puts "Should not execute"
      puts "No result block should be created"
      ```
    MARKDOWN
    create_md_file(md_content_run_false)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    expected_output = <<~MARKDOWN.strip
      ```ruby run=false
      puts "Should not execute"
      puts "No result block should be created"
      ```
    MARKDOWN
    assert_equal expected_output, read_md_file.strip

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

    expected_output = <<~MARKDOWN.strip
      ```ruby run=false
      puts "Should not execute"
      ```

      ```ruby RESULT
      Old result that should be preserved
      ```
    MARKDOWN
    assert_equal expected_output, read_md_file.strip

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

    expected_output = <<~MARKDOWN.strip
      ```ruby run=false rerun=true
      puts "Should not execute despite rerun=true"
      ```

      ```ruby RESULT
      Existing result
      ```
    MARKDOWN
    assert_equal expected_output, read_md_file.strip

    # Test 6: Combined options - run=true with rerun=false should execute if no result exists
    md_content_run_true_rerun_false = <<~MARKDOWN
      ```ruby run=true rerun=false
      puts "Should execute because no result exists"
      ```
    MARKDOWN
    create_md_file(md_content_run_true_rerun_false)
    MarkdownRun.run_code_blocks(@test_md_file_path)

    expected_output = <<~MARKDOWN.strip
      ```ruby run=true rerun=false
      puts "Should execute because no result exists"
      ```

      ```ruby RESULT
      puts "Should execute because no result exists"
      # >> Should execute because no result exists
      ```
    MARKDOWN
    assert_equal expected_output, read_md_file.strip
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
    # Extract the actual SVG filename from the output and build expected output
    svg_match = file_content.match(/!\[Mermaid Diagram\]\((.+\.svg)\)/)
    assert svg_match, "Should find generated SVG filename in output"
    actual_svg_filename = svg_match[1]

    expected_output = <<~MARKDOWN.strip
      ```mermaid
      graph TD
          A[Start] --> B[Process]
          B --> C[End]
      ```

      ![Mermaid Diagram](#{actual_svg_filename})
    MARKDOWN
    assert_equal expected_output, file_content.strip
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
    # Extract the actual timestamp from the output and build expected output
    timestamp_match = file_content.match(/Standalone rerun test: (\d+)/)
    assert timestamp_match, "Should find generated timestamp in output"
    actual_timestamp = timestamp_match[1]

    expected_output = <<~MARKDOWN.strip
      ```ruby rerun
      puts "Standalone rerun test: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      puts "Standalone rerun test: \#{Time.now.to_i}"
      # >> Standalone rerun test: #{actual_timestamp}
      ```
    MARKDOWN
    assert_equal expected_output, file_content.strip

    # Test 2: standalone run should work like run=true (default behavior)
    md_content_standalone_run = <<~MARKDOWN
      ```ruby run
      puts "Standalone run test"
      ```
    MARKDOWN
    test_file_2 = File.join(@temp_dir, "test2.md")
    File.write(test_file_2, md_content_standalone_run)
    MarkdownRun.run_code_blocks(test_file_2)

    expected_output = <<~MARKDOWN.strip
      ```ruby run
      puts "Standalone run test"
      ```

      ```ruby RESULT
      puts "Standalone run test"
      # >> Standalone run test
      ```
    MARKDOWN
    assert_equal expected_output, File.read(test_file_2).strip

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

    expected_output = <<~MARKDOWN.strip
      ```ruby rerun run=false
      puts "Execution test: \#{Time.now.to_i}"
      ```

      ```ruby RESULT
      Existing result to preserve
      ```
    MARKDOWN
    assert_equal expected_output, File.read(test_file_3).strip
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

    expected_output = <<~MARKDOWN.strip
      ```ruby result=false run
      puts "This result should be hidden"
      ```
    MARKDOWN
    assert_equal expected_output, File.read(test_file_1).strip

    # Test 2: result=true should show the result block (explicit true)
    md_content_result_true = <<~MARKDOWN
      ```ruby result=true run
      puts "This result should be visible"
      ```
    MARKDOWN
    test_file_2 = File.join(@temp_dir, "test_result_true.md")
    File.write(test_file_2, md_content_result_true)
    MarkdownRun.run_code_blocks(test_file_2)

    expected_output = <<~MARKDOWN.strip
      ```ruby result=true run
      puts "This result should be visible"
      ```

      ```ruby RESULT
      puts "This result should be visible"
      # >> This result should be visible
      ```
    MARKDOWN
    assert_equal expected_output, File.read(test_file_2).strip

    # Test 3: Default behavior (no result option) should show result block
    md_content_default = <<~MARKDOWN
      ```ruby run
      puts "Default behavior result"
      ```
    MARKDOWN
    test_file_3 = File.join(@temp_dir, "test_result_default.md")
    File.write(test_file_3, md_content_default)
    MarkdownRun.run_code_blocks(test_file_3)

    expected_output = <<~MARKDOWN.strip
      ```ruby run
      puts "Default behavior result"
      ```

      ```ruby RESULT
      puts "Default behavior result"
      # >> Default behavior result
      ```
    MARKDOWN
    assert_equal expected_output, File.read(test_file_3).strip

    # Test 4: Standalone result option should default to true
    md_content_standalone = <<~MARKDOWN
      ```ruby result run
      puts "Standalone result option"
      ```
    MARKDOWN
    test_file_4 = File.join(@temp_dir, "test_result_standalone.md")
    File.write(test_file_4, md_content_standalone)
    MarkdownRun.run_code_blocks(test_file_4)

    expected_output = <<~MARKDOWN.strip
      ```ruby result run
      puts "Standalone result option"
      ```

      ```ruby RESULT
      puts "Standalone result option"
      # >> Standalone result option
      ```
    MARKDOWN
    assert_equal expected_output, File.read(test_file_4).strip
  end
end
