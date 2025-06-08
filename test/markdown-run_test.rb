require_relative 'test_helper'

# --- Minitest Test Class Definition ---
class TestMarkdownRun < Minitest::Test
  include MarkdownTestHelper

  def test_script_runs_without_error_on_empty_file
    create_md_file("")
    assert MarkdownRun.run_code_blocks(@test_md_file_path), "Processing empty file should succeed"
    assert_equal "", read_md_file.strip, "Empty file should remain empty after processing"
  end

  def test_rerun_functionality
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
  end

  def test_fixtures
    run_fixture_tests
  end
end
