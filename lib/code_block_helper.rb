module CodeBlockHelper
  private

  def reset_code_block_state
    @state = :outside_code_block
    @current_code_content = ""
    @current_block_lang = ""


    @current_block_rerun = false
    @current_block_run = true
    @current_block_explain = false
    @current_block_flamegraph = false
    @current_block_result = true
  end


  def start_code_block(current_line, lang, options_string = nil)
    @output_lines << current_line
    @current_block_lang = resolve_language(lang)
    @current_block_rerun = @code_block_parser.parse_rerun_option(options_string, @current_block_lang)
    @current_block_run = @code_block_parser.parse_run_option(options_string, @current_block_lang)
    @current_block_explain = @code_block_parser.parse_explain_option(options_string, @current_block_lang)
    @current_block_flamegraph = @code_block_parser.parse_flamegraph_option(options_string, @current_block_lang)
    @current_block_result = @code_block_parser.parse_result_option(options_string, @current_block_lang)
    @state = :inside_code_block
    @current_code_content = ""
  end

  def accumulate_code_content(current_line)
    @current_code_content += current_line
    @output_lines << current_line
  end

  def end_code_block(current_line, file_enum)
    @output_lines << current_line

    decision = decide_execution(file_enum)

    if decision[:execute]
      # If we consumed lines for rerun, don't add them to output (they'll be replaced)
      execute_and_add_result(decision[:blank_line])
    else
      skip_and_pass_through_result(decision[:lines_to_pass_through], file_enum, decision)
    end

    reset_code_block_state
  end

  def decide_execution(file_enum)
    decider = ExecutionDecider.new(@current_block_run, @current_block_rerun, @current_block_lang, @current_block_explain, @current_block_flamegraph, @current_block_result)
    decision = decider.decide(file_enum, method(:result_block_regex))

    # Handle the consume_existing flag for rerun scenarios
    if decision[:consume_existing]
      consume_existing_result_block(file_enum, decision[:consumed_lines])
    elsif decision[:consume_existing_dalibo]
      # Dalibo links are already consumed in the decision process
      # Just acknowledge they were consumed
    end

    decision
  end
end
