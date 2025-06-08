require_relative 'test_helper'
require_relative '../lib/execution_decider'
require_relative '../lib/enum_helper'

# --- Minitest Test Class Definition ---
class TestExecutionDecider < Minitest::Test

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

  private

  # Helper method to create a simple file enum for testing
  def create_file_enum(lines)
    lines.to_enum
  end
end
