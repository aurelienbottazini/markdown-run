require_relative "enum_helper"

class ExecutionDecider
  include EnumHelper

  def initialize(current_block_run, current_block_rerun, current_block_lang, current_block_explain = false, current_block_flamegraph = false, current_block_result = true)
    @current_block_run = current_block_run
    @current_block_rerun = current_block_rerun
    @current_block_lang = current_block_lang
    @current_block_explain = current_block_explain
    @current_block_flamegraph = current_block_flamegraph
    @current_block_result = current_block_result
  end

  def decide(file_enum, result_block_regex_method, code_content = nil)
    return skip_execution_run_false if run_disabled?

    # For ruby blocks, check if code content contains xmpfilter results (# >>)
    if is_ruby_block? && code_content && has_xmpfilter_results?(code_content)
      return handle_inline_ruby_results
    end

    expected_header_regex = result_block_regex_method.call(@current_block_lang)
    peek1 = peek_next_line(file_enum)

    if line_matches_pattern?(peek1, expected_header_regex)
      handle_immediate_result_block(file_enum)
    elsif is_blank_line?(peek1)
      handle_blank_line_scenario(file_enum, expected_header_regex)
    elsif (@current_block_explain || @current_block_flamegraph) && is_dalibo_link?(peek1)
      handle_immediate_dalibo_link(file_enum)
    elsif @current_block_flamegraph && is_flamegraph_link?(peek1)
      handle_immediate_flamegraph_link(file_enum)
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

    # Look ahead past multiple blank lines to find actual content
    peek2 = peek_next_line(file_enum)
    additional_blanks = []

    # Consume consecutive blank lines
    while is_blank_line?(peek2)
      additional_blanks << file_enum.next
      peek2 = peek_next_line(file_enum)
    end

    if line_matches_pattern?(peek2, expected_header_regex)
      handle_result_after_blank_lines(file_enum, consumed_blank_line, additional_blanks)
    elsif (@current_block_explain || @current_block_flamegraph) && is_dalibo_link?(peek2)
      handle_dalibo_after_blank_lines(file_enum, consumed_blank_line, additional_blanks)
    elsif @current_block_flamegraph && is_flamegraph_link?(peek2)
      handle_flamegraph_after_blank_lines(file_enum, consumed_blank_line, additional_blanks)
    else
      execute_with_blank_lines(consumed_blank_line, additional_blanks)
    end
  end

  def handle_result_after_blank_line(file_enum, consumed_blank_line)
    if @current_block_rerun
      execute_with_consumed_result_and_blank(file_enum, consumed_blank_line)
    else
      skip_with_blank_and_result(file_enum, consumed_blank_line)
    end
  end

  def handle_result_after_blank_lines(file_enum, consumed_blank_line, additional_blanks)
    if @current_block_rerun
      execute_with_consumed_result_and_blanks(file_enum, consumed_blank_line, additional_blanks)
    else
      skip_with_blanks_and_result(file_enum, consumed_blank_line, additional_blanks)
    end
  end

  def handle_dalibo_after_blank_lines(file_enum, consumed_blank_line, additional_blanks)
    # For explain result=false, always replace existing Dalibo links
    # For explain result=true, follow normal rerun logic
    if should_auto_replace_dalibo_link? || @current_block_rerun
      execute_with_consumed_dalibo_and_blanks(file_enum, consumed_blank_line, additional_blanks)
    else
      skip_with_blanks_and_dalibo(file_enum, consumed_blank_line, additional_blanks)
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

  def execute_with_blank_lines(consumed_blank_line, additional_blanks)
    { execute: true, blank_line: consumed_blank_line, additional_blanks: additional_blanks }
  end

  def execute_with_consumed_result_and_blanks(file_enum, consumed_blank_line, additional_blanks)
    consumed_lines = [consumed_blank_line] + additional_blanks + [file_enum.next]
    { execute: true, consumed_lines: consumed_lines, blank_line: consumed_blank_line, consume_existing: true }
  end

  def skip_with_blanks_and_result(file_enum, consumed_blank_line, additional_blanks)
    lines_to_pass = [consumed_blank_line] + additional_blanks + [file_enum.next]
    { execute: false, lines_to_pass_through: lines_to_pass }
  end

  def execute_with_consumed_dalibo_and_blanks(file_enum, consumed_blank_line, additional_blanks)
    consumed_lines = [consumed_blank_line] + additional_blanks
    consume_dalibo_links(file_enum, consumed_lines)
    { execute: true, consumed_lines: consumed_lines, blank_line: consumed_blank_line, consume_existing_dalibo: true }
  end

  def skip_with_blanks_and_dalibo(file_enum, consumed_blank_line, additional_blanks)
    consumed_lines = [consumed_blank_line] + additional_blanks
    consume_dalibo_links(file_enum, consumed_lines)
    { execute: false, lines_to_pass_through: consumed_lines, dalibo_content: true }
  end

  def execute_without_existing_result
    { execute: true }
  end

  def handle_immediate_dalibo_link(file_enum)
    # For explain result=false, always replace existing Dalibo links
    # For explain result=true, follow normal rerun logic
    if should_auto_replace_dalibo_link? || @current_block_rerun
      execute_with_consumed_dalibo(file_enum)
    else
      skip_with_existing_dalibo(file_enum)
    end
  end

  def handle_dalibo_after_blank_line(file_enum, consumed_blank_line)
    # For explain result=false, always replace existing Dalibo links
    # For explain result=true, follow normal rerun logic
    if should_auto_replace_dalibo_link? || @current_block_rerun
      execute_with_consumed_dalibo_and_blank(file_enum, consumed_blank_line)
    else
      skip_with_blank_and_dalibo(file_enum, consumed_blank_line)
    end
  end

  def execute_with_consumed_dalibo(file_enum)
    consumed_lines = []
    consume_dalibo_links(file_enum, consumed_lines)
    { execute: true, consumed_lines: consumed_lines, consume_existing_dalibo: true }
  end

  def skip_with_existing_dalibo(file_enum)
    consumed_lines = []
    consume_dalibo_links(file_enum, consumed_lines)
    { execute: false, lines_to_pass_through: consumed_lines, dalibo_content: true }
  end

  def execute_with_consumed_dalibo_and_blank(file_enum, consumed_blank_line)
    consumed_lines = [consumed_blank_line]
    consume_dalibo_links(file_enum, consumed_lines)
    { execute: true, consumed_lines: consumed_lines, blank_line: consumed_blank_line, consume_existing_dalibo: true }
  end

  def skip_with_blank_and_dalibo(file_enum, consumed_blank_line)
    consumed_lines = [consumed_blank_line]
    consume_dalibo_links(file_enum, consumed_lines)
    { execute: false, lines_to_pass_through: consumed_lines, dalibo_content: true }
  end

  def consume_dalibo_links(file_enum, consumed_lines)
    # Consume all consecutive Dalibo links and blank lines
    loop do
      next_line = peek_next_line(file_enum)

      if is_blank_line?(next_line) || is_dalibo_link?(next_line)
        consumed_line = file_enum.next
        consumed_lines << consumed_line
      else
        break
      end
    end
  end

  def is_dalibo_link?(line)
    line&.start_with?("[Dalibo]")
  end

  def line_matches_pattern?(line, pattern)
    line && line.match?(pattern)
  end

  def is_blank_line?(line)
    line && line.strip == ""
  end

  def should_auto_replace_dalibo_link?
    # Auto-replace Dalibo links when using explain or flamegraph with result=false
    # This makes sense because with result=false, there's only a Dalibo link,
    # so it should be updated on each run
    (@current_block_explain || @current_block_flamegraph) && !@current_block_result
  end

  def is_flamegraph_link?(line)
    line&.start_with?("![PostgreSQL Query Flamegraph]")
  end

  def handle_flamegraph_after_blank_lines(file_enum, consumed_blank_line, additional_blanks)
    # For flamegraph result=false, always replace existing flamegraph links
    # For flamegraph result=true, follow normal rerun logic
    if should_auto_replace_flamegraph_link? || @current_block_rerun
      execute_with_consumed_flamegraph_and_blanks(file_enum, consumed_blank_line, additional_blanks)
    else
      skip_with_blanks_and_flamegraph(file_enum, consumed_blank_line, additional_blanks)
    end
  end

  def handle_immediate_flamegraph_link(file_enum)
    # For flamegraph result=false, always replace existing flamegraph links
    # For flamegraph result=true, follow normal rerun logic
    if should_auto_replace_flamegraph_link? || @current_block_rerun
      execute_with_consumed_flamegraph(file_enum)
    else
      skip_with_existing_flamegraph(file_enum)
    end
  end

  def execute_with_consumed_flamegraph(file_enum)
    consumed_lines = []
    consume_flamegraph_links(file_enum, consumed_lines)
    { execute: true, consumed_lines: consumed_lines, consume_existing_flamegraph: true }
  end

  def skip_with_existing_flamegraph(file_enum)
    consumed_lines = []
    consume_flamegraph_links(file_enum, consumed_lines)
    { execute: false, lines_to_pass_through: consumed_lines, flamegraph_content: true }
  end

  def execute_with_consumed_flamegraph_and_blanks(file_enum, consumed_blank_line, additional_blanks)
    consumed_lines = [consumed_blank_line] + additional_blanks
    consume_flamegraph_links(file_enum, consumed_lines)
    { execute: true, consumed_lines: consumed_lines, blank_line: consumed_blank_line, consume_existing_flamegraph: true }
  end

  def skip_with_blanks_and_flamegraph(file_enum, consumed_blank_line, additional_blanks)
    consumed_lines = [consumed_blank_line] + additional_blanks
    consume_flamegraph_links(file_enum, consumed_lines)
    { execute: false, lines_to_pass_through: consumed_lines, flamegraph_content: true }
  end

  def consume_flamegraph_links(file_enum, consumed_lines)
    # Consume all consecutive flamegraph links and blank lines
    loop do
      next_line = peek_next_line(file_enum)

      if is_blank_line?(next_line) || is_flamegraph_link?(next_line)
        consumed_line = file_enum.next
        consumed_lines << consumed_line
      else
        break
      end
    end
  end

  def should_auto_replace_flamegraph_link?
    # Auto-replace flamegraph links when using flamegraph with result=false
    # This makes sense because with result=false, there's only a flamegraph link,
    # so it should be updated on each run
    @current_block_flamegraph && !@current_block_result
  end

  def is_ruby_block?
    @current_block_lang == "ruby"
  end

  def has_xmpfilter_results?(code_content)
    # Check if code contains xmpfilter comment markers (# >>)
    code_content.include?("# >>")
  end

  def handle_inline_ruby_results
    if @current_block_rerun
      # Rerun requested, so execute and replace inline results
      { execute: true }
    else
      # Has inline results and rerun not requested, skip execution
      { execute: false, lines_to_pass_through: [] }
    end
  end
end
