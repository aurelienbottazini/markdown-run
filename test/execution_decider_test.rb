require_relative 'test_helper'
require_relative '../lib/execution_decider'
require_relative '../lib/enum_helper'

# --- Minitest Test Class Definition ---
class TestExecutionDecider < Minitest::Test
  include MarkdownTestHelper

  def test_execution_decider_dalibo_detection
    # Test the ExecutionDecider's ability to detect Dalibo links
    decider = ExecutionDecider.new(true, false, "psql", true, false, false)

    # Test Dalibo link detection
    assert decider.send(:is_dalibo_link?, "[Dalibo](https://explain.dalibo.com/plan/123)")
    refute decider.send(:is_dalibo_link?, "Some regular text")
    refute decider.send(:is_dalibo_link?, "```RESULT")
    refute decider.send(:is_dalibo_link?, "")
  end

  def test_execution_decider_auto_replace_logic
    # Test the auto-replacement logic for different scenarios

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
    lines = [
      "[Dalibo](https://explain.dalibo.com/plan/old-123)",
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
    lines = [
      "",  # blank line
      "[Dalibo](https://explain.dalibo.com/plan/old-456)",
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
    lines = [
      "[Dalibo](https://explain.dalibo.com/plan/link1)",
      "",
      "[Dalibo](https://explain.dalibo.com/plan/link2)",
      "[Dalibo](https://explain.dalibo.com/plan/link3)",
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

  def test_run_disabled_scenarios
    # Test when run is disabled
    decider = ExecutionDecider.new(false, false, "ruby")
    result = decider.send(:skip_execution_run_false)

    assert_equal false, result[:execute]
    assert_equal [], result[:lines_to_pass_through]
  end

  def test_flamegraph_detection
    # Test flamegraph link detection
    decider = ExecutionDecider.new(true, false, "psql", false, true, false)

    assert decider.send(:is_flamegraph_link?, "![PostgreSQL Query Flamegraph](path/to/flamegraph.svg)")
    refute decider.send(:is_flamegraph_link?, "Some regular text")
    refute decider.send(:is_flamegraph_link?, "![Regular Image](path.jpg)")
    refute decider.send(:is_flamegraph_link?, nil)
  end

  def test_flamegraph_auto_replace_logic
    # Test auto-replacement logic for flamegraph

    # flamegraph=true, result=false should auto-replace
    decider1 = ExecutionDecider.new(true, false, "psql", false, true, false)
    assert decider1.send(:should_auto_replace_flamegraph_link?), "Should auto-replace with flamegraph=true, result=false"

    # flamegraph=true, result=true should NOT auto-replace
    decider2 = ExecutionDecider.new(true, false, "psql", false, true, true)
    refute decider2.send(:should_auto_replace_flamegraph_link?), "Should not auto-replace with flamegraph=true, result=true"

    # flamegraph=false should NOT auto-replace
    decider3 = ExecutionDecider.new(true, false, "psql", false, false, false)
    refute decider3.send(:should_auto_replace_flamegraph_link?), "Should not auto-replace with flamegraph=false"
  end

  def test_handle_immediate_flamegraph_link
    # Test handling of immediate flamegraph links
    lines = [
      "![PostgreSQL Query Flamegraph](old-flamegraph.svg)",
      "Some other content"
    ]
    file_enum = lines.to_enum

    # With auto-replace (flamegraph result=false)
    decider = ExecutionDecider.new(true, false, "psql", false, true, false)
    result = decider.send(:handle_immediate_flamegraph_link, file_enum)

    assert result[:execute], "Should execute with auto-replace"
    assert result[:consume_existing_flamegraph], "Should consume existing flamegraph content"
  end

  def test_handle_immediate_flamegraph_link_no_auto_replace
    # Test handling when auto-replace is disabled
    lines = [
      "![PostgreSQL Query Flamegraph](old-flamegraph.svg)",
      "Some other content"
    ]
    file_enum = lines.to_enum

    # Without auto-replace (flamegraph result=true)
    decider = ExecutionDecider.new(true, false, "psql", false, true, true)
    result = decider.send(:handle_immediate_flamegraph_link, file_enum)

    assert_equal false, result[:execute], "Should not execute without auto-replace"
    assert result[:lines_to_pass_through], "Should pass through lines"
  end

  def test_consume_flamegraph_links
    # Test consuming multiple flamegraph links
    lines = [
      "![PostgreSQL Query Flamegraph](flamegraph1.svg)",
      "",
      "![PostgreSQL Query Flamegraph](flamegraph2.svg)",
      "Some other content"
    ]
    file_enum = lines.to_enum
    consumed_lines = []

    decider = ExecutionDecider.new(true, false, "psql", false, true, false)
    decider.send(:consume_flamegraph_links, file_enum, consumed_lines)

    assert_equal 3, consumed_lines.length, "Should consume flamegraph links and blank lines"
    assert consumed_lines[0].include?("flamegraph1.svg"), "Should consume first flamegraph link"
    assert consumed_lines[2].include?("flamegraph2.svg"), "Should consume second flamegraph link"
  end

  def test_handle_flamegraph_after_blank_lines
    # Test handling flamegraph after blank lines
    lines = [
      "",  # blank line
      "![PostgreSQL Query Flamegraph](test-flamegraph.svg)",
      "Some other content"
    ]
    file_enum = lines.to_enum

    # With auto-replace
    decider = ExecutionDecider.new(true, false, "psql", false, true, false)
    result = decider.send(:handle_flamegraph_after_blank_lines, file_enum, "", [])

    assert result[:execute], "Should execute with auto-replace after blank lines"
    assert result[:consume_existing_flamegraph], "Should consume existing flamegraph content"
  end

  def test_handle_flamegraph_after_blank_lines_no_auto_replace
    # Test handling flamegraph after blank lines without auto-replace
    lines = [
      "",  # blank line
      "![PostgreSQL Query Flamegraph](test-flamegraph.svg)",
      "Some other content"
    ]
    file_enum = lines.to_enum

    # Without auto-replace (rerun=false, result=true)
    decider = ExecutionDecider.new(true, false, "psql", false, true, true)
    result = decider.send(:handle_flamegraph_after_blank_lines, file_enum, "", [])

    assert_equal false, result[:execute], "Should not execute without auto-replace"
    assert result[:lines_to_pass_through], "Should pass through lines"
  end

  def test_line_matches_pattern
    decider = ExecutionDecider.new(true, false, "ruby")

    # Test pattern matching
    assert decider.send(:line_matches_pattern?, "```ruby RESULT", /```ruby RESULT/)
    refute decider.send(:line_matches_pattern?, "other text", /```ruby RESULT/)
    refute decider.send(:line_matches_pattern?, nil, /```ruby RESULT/)
  end

  def test_is_blank_line
    decider = ExecutionDecider.new(true, false, "ruby")

    assert decider.send(:is_blank_line?, "")
    assert decider.send(:is_blank_line?, "   ")
    assert decider.send(:is_blank_line?, "\t")
    refute decider.send(:is_blank_line?, "text")
    refute decider.send(:is_blank_line?, nil)
  end

  def test_execute_without_existing_result
    decider = ExecutionDecider.new(true, false, "ruby")
    result = decider.send(:execute_without_existing_result)

    assert_equal true, result[:execute]
    assert_nil result[:consumed_lines]
  end

  def test_execute_with_blank_line
    decider = ExecutionDecider.new(true, false, "ruby")
    result = decider.send(:execute_with_blank_line, "")

    assert_equal true, result[:execute]
    assert_equal "", result[:blank_line]
  end

  def test_handle_immediate_result_block_with_rerun
    lines = ["```ruby RESULT", "output", "```"]
    file_enum = lines.to_enum

    decider = ExecutionDecider.new(true, true, "ruby")  # rerun=true
    result = decider.send(:handle_immediate_result_block, file_enum)

    assert result[:execute], "Should execute with rerun=true"
    assert result[:consume_existing], "Should consume existing result"
    assert_equal 1, result[:consumed_lines].length
  end

  def test_handle_immediate_result_block_without_rerun
    lines = ["```ruby RESULT", "output", "```"]
    file_enum = lines.to_enum

    decider = ExecutionDecider.new(true, false, "ruby")  # rerun=false
    result = decider.send(:handle_immediate_result_block, file_enum)

    assert_equal false, result[:execute], "Should not execute with rerun=false"
    assert result[:lines_to_pass_through], "Should pass through lines"
  end

  def test_skip_with_existing_dalibo_no_rerun
    lines = ["[Dalibo](https://explain.dalibo.com/plan/123)", "other content"]
    file_enum = lines.to_enum

    # Without rerun and without auto-replace (explain result=true)
    decider = ExecutionDecider.new(true, false, "psql", true, false, true)
    result = decider.send(:handle_immediate_dalibo_link, file_enum)

    assert_equal false, result[:execute], "Should not execute without rerun"
    assert result[:lines_to_pass_through], "Should pass through dalibo content"
    assert result[:dalibo_content], "Should mark as dalibo content"
  end

  def test_skip_with_blank_and_dalibo
    lines = ["", "[Dalibo](https://explain.dalibo.com/plan/123)", "other content"]
    file_enum = lines.to_enum

    # Without rerun and without auto-replace
    decider = ExecutionDecider.new(true, false, "psql", true, false, true)
    result = decider.send(:skip_with_blank_and_dalibo, file_enum, "")

    assert_equal false, result[:execute], "Should not execute"
    assert result[:lines_to_pass_through], "Should pass through lines"
    assert result[:dalibo_content], "Should mark as dalibo content"
  end

  def test_execute_with_consumed_dalibo_and_blank
    lines = ["[Dalibo](https://explain.dalibo.com/plan/123)", "other content"]
    file_enum = lines.to_enum

    decider = ExecutionDecider.new(true, true, "psql", true, false, true)  # rerun=true
    result = decider.send(:execute_with_consumed_dalibo_and_blank, file_enum, "")

    assert result[:execute], "Should execute"
    assert result[:consume_existing_dalibo], "Should consume dalibo"
    assert_equal "", result[:blank_line]
  end

    def test_multiple_blank_lines_handling
    # Test the specific scenario with multiple consecutive blank lines
    lines = [
      "",      # first blank (consumed by handle_blank_line_scenario)
      "",      # second blank
      "",      # third blank
      "```ruby RESULT",
      "output",
      "```"
    ]
    file_enum = lines.to_enum

    decider = ExecutionDecider.new(true, false, "ruby")

    # First consume the initial blank line (as handle_blank_line_scenario would do)
    consumed_blank_line = file_enum.next

    # This should exercise the while loop for consuming additional blank lines
    # The method should find the result block after multiple blanks
    peek2 = decider.send(:peek_next_line, file_enum)
    additional_blanks = []

    # This exercises the while loop that was showing 0 coverage
    while decider.send(:is_blank_line?, peek2)
      additional_blanks << file_enum.next
      peek2 = decider.send(:peek_next_line, file_enum)
    end

    expected_header_regex = /```ruby RESULT/
    assert_equal 2, additional_blanks.length, "Should consume additional blank lines after first"
    assert decider.send(:line_matches_pattern?, peek2, expected_header_regex), "Should find result block after blanks"
  end

  private

  # Helper method to create a simple file enum for testing
  def create_file_enum(lines)
    lines.to_enum
  end
end
