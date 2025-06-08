require_relative 'test_helper'
require_relative '../lib/flamegraph_helper'

class FlamegraphHelperTest < Minitest::Test
  # Create a test class that includes the module so we can test the private methods
  class TestIncluder
    include FlamegraphHelper

    # Expose private methods for testing
    def public_extract_flamegraph_link(result_output)
      extract_flamegraph_link(result_output)
    end

    def public_consume_flamegraph_link_if_present(file_enum, consumed_lines)
      consume_flamegraph_link_if_present(file_enum, consumed_lines)
    end

    # Mock the helper methods that would normally come from other modules
    def peek_next_line(file_enum)
      file_enum.peek
    rescue StopIteration
      nil
    end

    def is_blank_line?(line)
      line.nil? || line.strip.empty?
    end
  end

  def setup
    @helper = TestIncluder.new
  end

  def test_flamegraph_link_prefix_constant
    assert_equal "FLAMEGRAPH_LINK:", FlamegraphHelper::FLAMEGRAPH_LINK_PREFIX
  end

  def test_extract_flamegraph_link_with_link_prefix
    result_output = "FLAMEGRAPH_LINK:/path/to/flamegraph.svg\nQuery execution completed successfully"

    flamegraph_link, clean_result = @helper.public_extract_flamegraph_link(result_output)

    assert_equal "![PostgreSQL Query Flamegraph](/path/to/flamegraph.svg)", flamegraph_link
    assert_equal "Query execution completed successfully", clean_result
  end

  def test_extract_flamegraph_link_with_link_prefix_no_additional_content
    result_output = "FLAMEGRAPH_LINK:/path/to/flamegraph.svg"

    flamegraph_link, clean_result = @helper.public_extract_flamegraph_link(result_output)

    assert_equal "![PostgreSQL Query Flamegraph](/path/to/flamegraph.svg)", flamegraph_link
    assert_equal "", clean_result
  end

  def test_extract_flamegraph_link_with_link_prefix_empty_path
    result_output = "FLAMEGRAPH_LINK:\nSome result content"

    flamegraph_link, clean_result = @helper.public_extract_flamegraph_link(result_output)

    assert_equal "![PostgreSQL Query Flamegraph]()", flamegraph_link
    assert_equal "Some result content", clean_result
  end

  def test_extract_flamegraph_link_with_link_prefix_multiline_result
    result_output = "FLAMEGRAPH_LINK:/complex/path/flamegraph.svg\nLine 1 of result\nLine 2 of result\nLine 3 of result"

    flamegraph_link, clean_result = @helper.public_extract_flamegraph_link(result_output)

    assert_equal "![PostgreSQL Query Flamegraph](/complex/path/flamegraph.svg)", flamegraph_link
    assert_equal "Line 1 of result\nLine 2 of result\nLine 3 of result", clean_result
  end

  def test_extract_flamegraph_link_without_link_prefix
    result_output = "Regular query result without flamegraph link"

    flamegraph_link, clean_result = @helper.public_extract_flamegraph_link(result_output)

    assert_nil flamegraph_link
    assert_equal "Regular query result without flamegraph link", clean_result
  end

  def test_extract_flamegraph_link_partial_prefix_match
    result_output = "FLAMEGRAPH_LINK_PARTIAL:/path/to/file.svg\nResult content"

    flamegraph_link, clean_result = @helper.public_extract_flamegraph_link(result_output)

    assert_nil flamegraph_link
    assert_equal "FLAMEGRAPH_LINK_PARTIAL:/path/to/file.svg\nResult content", clean_result
  end

  def test_extract_flamegraph_link_empty_input
    result_output = ""

    flamegraph_link, clean_result = @helper.public_extract_flamegraph_link(result_output)

    assert_nil flamegraph_link
    assert_equal "", clean_result
  end

  def test_consume_flamegraph_link_if_present_with_blank_lines_and_flamegraph
    lines = [
      "",
      "  ",
      "![PostgreSQL Query Flamegraph](/path/to/graph1.svg)",
      "",
      "![PostgreSQL Query Flamegraph](/path/to/graph2.svg)",
      "Next content line"
    ]
    file_enum = lines.to_enum
    consumed_lines = []

    @helper.public_consume_flamegraph_link_if_present(file_enum, consumed_lines)

    expected_consumed = [
      "",
      "  ",
      "![PostgreSQL Query Flamegraph](/path/to/graph1.svg)",
      "",
      "![PostgreSQL Query Flamegraph](/path/to/graph2.svg)"
    ]
    assert_equal expected_consumed, consumed_lines

    # Verify that the next line is still available
    assert_equal "Next content line", file_enum.next
  end

  def test_consume_flamegraph_link_if_present_with_only_blank_lines
    lines = ["", "   ", "\t", "Non-blank content"]
    file_enum = lines.to_enum
    consumed_lines = []

    @helper.public_consume_flamegraph_link_if_present(file_enum, consumed_lines)

    expected_consumed = ["", "   ", "\t"]
    assert_equal expected_consumed, consumed_lines

    # Verify that the non-blank line is still available
    assert_equal "Non-blank content", file_enum.next
  end

  def test_consume_flamegraph_link_if_present_with_only_flamegraph_links
    lines = [
      "![PostgreSQL Query Flamegraph](/path1.svg)",
      "![PostgreSQL Query Flamegraph](/path2.svg)",
      "Some other content"
    ]
    file_enum = lines.to_enum
    consumed_lines = []

    @helper.public_consume_flamegraph_link_if_present(file_enum, consumed_lines)

    expected_consumed = [
      "![PostgreSQL Query Flamegraph](/path1.svg)",
      "![PostgreSQL Query Flamegraph](/path2.svg)"
    ]
    assert_equal expected_consumed, consumed_lines

    # Verify that the other content line is still available
    assert_equal "Some other content", file_enum.next
  end

  def test_consume_flamegraph_link_if_present_with_no_matching_content
    lines = ["Immediate non-matching content", "More content"]
    file_enum = lines.to_enum
    consumed_lines = []

    @helper.public_consume_flamegraph_link_if_present(file_enum, consumed_lines)

    assert_equal [], consumed_lines

    # Verify that all lines are still available
    assert_equal "Immediate non-matching content", file_enum.next
    assert_equal "More content", file_enum.next
  end

  def test_consume_flamegraph_link_if_present_end_of_file
    lines = ["", "![PostgreSQL Query Flamegraph](/path.svg)"]
    file_enum = lines.to_enum
    consumed_lines = []

    @helper.public_consume_flamegraph_link_if_present(file_enum, consumed_lines)

    expected_consumed = ["", "![PostgreSQL Query Flamegraph](/path.svg)"]
    assert_equal expected_consumed, consumed_lines

    # Verify that we've reached the end
    assert_raises(StopIteration) { file_enum.next }
  end

  def test_consume_flamegraph_link_if_present_empty_enumerator
    file_enum = [].to_enum
    consumed_lines = []

    @helper.public_consume_flamegraph_link_if_present(file_enum, consumed_lines)

    assert_equal [], consumed_lines
  end

  def test_consume_flamegraph_link_if_present_mixed_content_complex
    lines = [
      "",
      "![PostgreSQL Query Flamegraph](/graph1.svg)",
      "",
      "",
      "![PostgreSQL Query Flamegraph](/graph2.svg)",
      "![PostgreSQL Query Flamegraph](/graph3.svg)",
      "",
      "![PostgreSQL Query Flamegraph](/graph4.svg)",
      "Non-flamegraph content"
    ]
    file_enum = lines.to_enum
    consumed_lines = []

    @helper.public_consume_flamegraph_link_if_present(file_enum, consumed_lines)

    expected_consumed = [
      "",
      "![PostgreSQL Query Flamegraph](/graph1.svg)",
      "",
      "",
      "![PostgreSQL Query Flamegraph](/graph2.svg)",
      "![PostgreSQL Query Flamegraph](/graph3.svg)",
      "",
      "![PostgreSQL Query Flamegraph](/graph4.svg)"
    ]
    assert_equal expected_consumed, consumed_lines

    # Verify that the non-flamegraph content is still available
    assert_equal "Non-flamegraph content", file_enum.next
  end

  def test_consume_flamegraph_link_if_present_similar_but_not_exact_flamegraph_link
    lines = [
      "",
      "![PostgreSQL Query Flamegraph Extra](/path.svg)",  # Not exact match
      "![PostgreSQL Query Flamegraph](/path.svg)",        # Exact match
      "Content"
    ]
    file_enum = lines.to_enum
    consumed_lines = []

    @helper.public_consume_flamegraph_link_if_present(file_enum, consumed_lines)

    # Should stop at the non-exact match
    expected_consumed = [""]
    assert_equal expected_consumed, consumed_lines

    # Verify that the non-exact match line is still available
    assert_equal "![PostgreSQL Query Flamegraph Extra](/path.svg)", file_enum.next
  end
end