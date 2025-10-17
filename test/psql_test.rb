require_relative 'test_helper'
require_relative '../lib/postgres_helper'

# --- PSQL-specific Tests ---
class TestPsql < Minitest::Test
  include MarkdownTestHelper

  def setup
    super
    # Reset PostgresHelper cache before each test
    PostgresHelper.reset_cache!
  end

  def test_explain_option_syntax
    # Test explain option parsing for psql
    skip("PostgreSQL not available") unless PostgresHelper.available?

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
    # Extract the dynamic explain result and build expected output
    result_match = file_content.match(/```RESULT\n(.*?)\n```\n\n(.*)$/m)
    assert result_match, "Should find RESULT block in output"
    actual_result = result_match[1]
    dalibo_link = result_match[2]

    expected_output = <<~MARKDOWN.strip
      ```psql explain
      SELECT 1 as simple_test;
      ```

      ```RESULT
      #{actual_result}
      ```

      #{dalibo_link}
    MARKDOWN
    assert_equal expected_output, file_content.strip

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
    # Extract the dynamic explain result and build expected output
    result_match = file_content.match(/```RESULT\n(.*?)\n```\n\n(.*)$/m)
    assert result_match, "Should find RESULT block in output"
    actual_result = result_match[1]
    dalibo_link = result_match[2]

    expected_output = <<~MARKDOWN.strip
      ```psql explain=true
      SELECT version();
      ```

      ```RESULT
      #{actual_result}
      ```

      #{dalibo_link}
    MARKDOWN
    assert_equal expected_output, file_content.strip

    # Test 3: Explicit explain=false should work normally
    test_file_3 = File.join(@temp_dir, "test_explain_false.md")
    md_content_false = <<~MARKDOWN
      ```psql explain=false
      SELECT 'normal query' as test;
      ```
    MARKDOWN
    File.write(test_file_3, md_content_false)
    MarkdownRun.run_code_blocks(test_file_3)

    expected_output = <<~MARKDOWN.strip
      ```psql explain=false
      SELECT 'normal query' as test;
      ```

      ```RESULT
      normal query
      ```
    MARKDOWN
    assert_equal expected_output, File.read(test_file_3).strip
  end

  def test_result_option_with_psql_explain
    skip("PostgreSQL not available") unless PostgresHelper.available?

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
    # Extract the dynamic explain result and build expected output
    result_match = file_content.match(/```RESULT\n(.*?)\n```\n\n(.*)$/m)
    assert result_match, "Should find RESULT block in output"
    actual_result = result_match[1]
    dalibo_link = result_match[2]

    expected_output = <<~MARKDOWN.strip
      ---
      markdown-run:
        psql:
          explain: true
      ---

      ```psql
      SELECT 'explain default test' as test;
      ```

      ```RESULT
      #{actual_result}
      ```

      #{dalibo_link}
    MARKDOWN
    assert_equal expected_output, file_content.strip
  end

  def test_frontmatter_defaults_with_psql_explain
    skip("PostgreSQL not available") unless PostgresHelper.available?

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
    # Extract the dynamic explain result and build expected output
    result_match = file_content.match(/```RESULT\n(.*?)\n```\n\n(.*)$/m)
    assert result_match, "Should find RESULT block in output"
    actual_result = result_match[1]
    dalibo_link = result_match[2]

    expected_output = <<~MARKDOWN.strip
      ---
      markdown-run:
        psql:
          explain: true
      ---

      ```psql
      SELECT 'explain default test' as test;
      ```

      ```RESULT
      #{actual_result}
      ```

      #{dalibo_link}
    MARKDOWN
    assert_equal expected_output, file_content.strip
  end
end
