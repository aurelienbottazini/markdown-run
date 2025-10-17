require_relative 'test_helper'

# --- Frontmatter Test Class Definition ---
class TestFrontmatter < Minitest::Test
  include MarkdownTestHelper

  def test_frontmatter_dynamic_timestamps
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
    # Extract the actual timestamp from the output and build expected output
    timestamp_match = file_content.match(/Global rerun test: (\d+)/)
    assert timestamp_match, "Should find generated timestamp in output"
    actual_timestamp = timestamp_match[1]

    expected_output = <<~MARKDOWN.strip
      ---
      markdown-run:
        defaults:
          rerun: true
      ---

      ```ruby
      puts "Global rerun test: \#{Time.now.to_i}"
      # >> Global rerun test: #{actual_timestamp}
      ```
    MARKDOWN
    assert_equal expected_output, file_content.strip

    # Test language-specific defaults with dynamic timestamps
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
    # Extract the actual timestamp from the output and build expected output
    timestamp_match = file_content.match(/Language-specific ruby test: (\d+)/)
    assert timestamp_match, "Should find generated timestamp in output"
    actual_timestamp = timestamp_match[1]

    expected_output = <<~MARKDOWN.strip
      ---
      markdown-run:
        ruby:
          rerun: true
        psql:
          explain: true
      ---

      ```ruby
      puts "Language-specific ruby test: \#{Time.now.to_i}"
      # >> Language-specific ruby test: #{actual_timestamp}
      ```
    MARKDOWN
    assert_equal expected_output, file_content.strip

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
    # Extract the actual timestamp from the output and build expected output
    timestamp_match = file_content.match(/Priority test: (\d+)/)
    assert timestamp_match, "Should find generated timestamp in output"
    actual_timestamp = timestamp_match[1]

    expected_output = <<~MARKDOWN.strip
      ---
      markdown-run:
        defaults:
          rerun: true
        ruby:
          rerun: false
      ---

      ```ruby rerun=true
      puts "Priority test: \#{Time.now.to_i}"
      # >> Priority test: #{actual_timestamp}
      ```
    MARKDOWN
    assert_equal expected_output, file_content.strip

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
    # Extract the actual timestamp from the output and build expected output
    timestamp_match = file_content.match(/Override test: (\d+)/)
    assert timestamp_match, "Should find generated timestamp in output"
    actual_timestamp = timestamp_match[1]

    expected_output = <<~MARKDOWN.strip
      ---
      markdown-run:
        defaults:
          rerun: false
        ruby:
          rerun: true
      ---

      ```ruby
      puts "Override test: \#{Time.now.to_i}"
      # >> Override test: #{actual_timestamp}
      ```
    MARKDOWN
    assert_equal expected_output, file_content.strip
  end
end
