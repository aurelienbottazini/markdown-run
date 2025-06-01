require_relative "enum_helper"

class ExecutionDecider
  include EnumHelper

  def initialize(current_block_run, current_block_rerun, current_block_lang)
    @current_block_run = current_block_run
    @current_block_rerun = current_block_rerun
    @current_block_lang = current_block_lang
  end

  def decide(file_enum, result_block_regex_method)
    return skip_execution_run_false if run_disabled?

    expected_header_regex = result_block_regex_method.call(@current_block_lang)
    peek1 = peek_next_line(file_enum)

    if line_matches_pattern?(peek1, expected_header_regex)
      handle_immediate_result_block(file_enum)
    elsif is_blank_line?(peek1)
      handle_blank_line_scenario(file_enum, expected_header_regex)
    else
      execute_without_existing_result
    end
  end

  private

  def run_disabled?
    !@current_block_run
  end

  def skip_execution_run_false
    { execute: false, lines_to_pass_through: [] }
  end

  def handle_immediate_result_block(file_enum)
    if @current_block_rerun
      execute_with_consumed_result(file_enum)
    else
      skip_with_existing_result(file_enum)
    end
  end

  def handle_blank_line_scenario(file_enum, expected_header_regex)
    consumed_blank_line = file_enum.next
    peek2 = peek_next_line(file_enum)

    if line_matches_pattern?(peek2, expected_header_regex)
      handle_result_after_blank_line(file_enum, consumed_blank_line)
    else
      execute_with_blank_line(consumed_blank_line)
    end
  end

  def handle_result_after_blank_line(file_enum, consumed_blank_line)
    if @current_block_rerun
      execute_with_consumed_result_and_blank(file_enum, consumed_blank_line)
    else
      skip_with_blank_and_result(file_enum, consumed_blank_line)
    end
  end

  def execute_with_consumed_result(file_enum)
    consumed_lines = [file_enum.next]
    { execute: true, consumed_lines: consumed_lines, consume_existing: true }
  end

  def skip_with_existing_result(file_enum)
    { execute: false, lines_to_pass_through: [file_enum.next] }
  end

  def execute_with_consumed_result_and_blank(file_enum, consumed_blank_line)
    consumed_lines = [consumed_blank_line, file_enum.next]
    { execute: true, consumed_lines: consumed_lines, blank_line: consumed_blank_line, consume_existing: true }
  end

  def skip_with_blank_and_result(file_enum, consumed_blank_line)
    { execute: false, lines_to_pass_through: [consumed_blank_line, file_enum.next] }
  end

  def execute_with_blank_line(consumed_blank_line)
    { execute: true, blank_line: consumed_blank_line }
  end

  def execute_without_existing_result
    { execute: true }
  end

  def line_matches_pattern?(line, pattern)
    line && line.match?(pattern)
  end

  def is_blank_line?(line)
    line && line.strip == ""
  end
end
