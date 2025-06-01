require "tempfile"
require "open3"
require_relative "language_configs"
require_relative "frontmatter_parser"
require_relative "enum_helper"

class MarkdownProcessor
  include EnumHelper
  def initialize(temp_dir)
    @temp_dir = temp_dir
    @output_lines = []
    @state = :outside_code_block
    @current_block_lang = ""
    @current_code_content = ""
    @current_block_rerun = false
    @current_block_run = true
    @frontmatter_parser = FrontmatterParser.new
  end

  def process_file(file_enum)
    @frontmatter_parser.parse_frontmatter(file_enum, @output_lines)

    loop do
      current_line = get_next_line(file_enum)
      break unless current_line

      handle_line(current_line, file_enum)
    end
    @output_lines
  end

  private

  def resolve_language(lang)
    @frontmatter_parser.resolve_language(lang)
  end

  def ruby_style_result?(lang)
    lang_config = SUPPORTED_LANGUAGES[lang]
    lang_config && lang_config[:result_block_type] == "ruby"
  end

  def result_block_header(lang)
    ruby_style_result?(lang) ? "```ruby RESULT\n" : "```RESULT\n"
  end

  def result_block_regex(lang)
    ruby_style_result?(lang) ? /^```ruby\s+RESULT$/i : /^```RESULT$/i
  end

  def is_block_end?(line)
    line.strip == "```"
  end

  def has_content?(content)
    !content.strip.empty?
  end

  def add_result_block(result_output, blank_line_before_new_result)
    @output_lines << "\n" if blank_line_before_new_result.nil?
    @output_lines << result_block_header(@current_block_lang)
    @output_lines << result_output
    @output_lines << "\n" unless result_output.empty? || result_output.end_with?("\n")
    @output_lines << "```\n\n"
  end

  def line_matches_pattern?(line, pattern)
    line && line.match?(pattern)
  end

  def is_blank_line?(line)
    line && line.strip == ""
  end

  def parse_rerun_option(options_string)
    parse_boolean_option(options_string, "rerun", false)
  end

  def parse_run_option(options_string)
    parse_boolean_option(options_string, "run", true)
  end

  def parse_boolean_option(options_string, option_name, default_value)
    return default_value unless options_string

    # Match option=true or option=false
    match = options_string.match(/#{option_name}\s*=\s*(true|false)/i)
    return default_value unless match

    match[1].downcase == "true"
  end

  def handle_line(current_line, file_enum)
    case @state
    when :outside_code_block
      handle_outside_code_block(current_line, file_enum)
    when :inside_code_block
      handle_inside_code_block(current_line, file_enum)
    when :inside_result_block
      handle_inside_result_block(current_line, file_enum)
    end
  end

  def handle_outside_code_block(current_line, file_enum)
    if current_line.match?(/^```ruby\s+RESULT$/i)
      handle_existing_ruby_result_block(current_line, file_enum)
    elsif (match_data = current_line.match(/^```(\w+)(?:\s+(.*))?$/i))
      lang = match_data[1].downcase
      options_string = match_data[2]
      resolved_lang = resolve_language(lang)
      if SUPPORTED_LANGUAGES.key?(resolved_lang)
        start_code_block(current_line, lang, options_string)
      else
        @output_lines << current_line
      end
    else
      @output_lines << current_line
    end
  end

  def handle_inside_code_block(current_line, file_enum)
    if is_block_end?(current_line)
      end_code_block(current_line, file_enum)
    else
      accumulate_code_content(current_line)
    end
  end

  def handle_inside_result_block(current_line, file_enum)
    @output_lines << current_line
    if is_block_end?(current_line)
      @state = :outside_code_block
    end
  end

  def handle_existing_ruby_result_block(current_line, file_enum)
    warn "Found existing '```ruby RESULT' block, passing through."
    @output_lines << current_line
    @state = :inside_result_block
  end

  def start_code_block(current_line, lang, options_string = nil)
    @output_lines << current_line
    @current_block_lang = resolve_language(lang)
    @current_block_rerun = parse_rerun_option(options_string)
    @current_block_run = parse_run_option(options_string)
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
      skip_and_pass_through_result(decision[:lines_to_pass_through], file_enum)
    end

    reset_code_block_state
  end

  def decide_execution(file_enum)
    # If run=false, skip execution entirely (no result block creation)
    unless @current_block_run
      return { execute: false, lines_to_pass_through: [] }
    end

    peek1 = peek_next_line(file_enum)
    expected_header_regex = result_block_regex(@current_block_lang)

    if line_matches_pattern?(peek1, expected_header_regex)
      # If rerun=true, execute even if result block exists
      if @current_block_rerun
        # Consume the existing result block and execute
        consumed_lines = [file_enum.next]
        consume_existing_result_block(file_enum, consumed_lines)
        return { execute: true, consumed_lines: consumed_lines }
      else
        return { execute: false, lines_to_pass_through: [file_enum.next] }
      end
    elsif is_blank_line?(peek1)
      consumed_blank_line = file_enum.next
      peek2 = peek_next_line(file_enum)

      if line_matches_pattern?(peek2, expected_header_regex)
        if @current_block_rerun
          # Consume the blank line and existing result block, then execute
          consumed_lines = [consumed_blank_line, file_enum.next]
          consume_existing_result_block(file_enum, consumed_lines)
          return { execute: true, consumed_lines: consumed_lines, blank_line: consumed_blank_line }
        else
          return { execute: false, lines_to_pass_through: [consumed_blank_line, file_enum.next] }
        end
      else
        return { execute: true, blank_line: consumed_blank_line }
      end
    else
      return { execute: true }
    end
  end

  def execute_and_add_result(blank_line_before_new_result)
    @output_lines << blank_line_before_new_result if blank_line_before_new_result

    if has_content?(@current_code_content)
      result_output = execute_code_block(@current_code_content, @current_block_lang, @temp_dir)
      add_result_block(result_output, blank_line_before_new_result)
    else
      warn "Skipping empty code block for language '#{@current_block_lang}'."
    end
  end

  def skip_and_pass_through_result(lines_to_pass_through, file_enum)
    # Handle run=false case where there are no lines to pass through
    if lines_to_pass_through.empty?
      warn "Skipping execution due to run=false option."
      return
    end

    lang_specific_result_type = ruby_style_result?(@current_block_lang) ? "```ruby RESULT" : "```RESULT"

    warn "Found existing '#{lang_specific_result_type}' block for current #{@current_block_lang} block, skipping execution."

    @output_lines.concat(lines_to_pass_through)

    consume_result_block_content(file_enum)
  end

  def consume_result_block_content(file_enum)
    consume_block_lines(file_enum) do |line|
      @output_lines << line
    end
  end

  def consume_existing_result_block(file_enum, consumed_lines)
    consume_block_lines(file_enum) do |line|
      consumed_lines << line
    end
  end

  def consume_block_lines(file_enum)
    begin
      loop do
        result_block_line = file_enum.next
        yield result_block_line
        break if is_block_end?(result_block_line)
      end
    rescue StopIteration
      warn "Warning: End of file reached while consuming result block."
    end
  end

  def reset_code_block_state
    @state = :outside_code_block
    @current_code_content = ""
    @current_block_rerun = false
    @current_block_run = true
  end

  def stderr_has_content?(stderr_output)
    stderr_output && !stderr_output.strip.empty?
  end

  def format_captured_output(captured_status_obj, captured_stderr, captured_stdout, lang_config)
    result_output = captured_stdout
    stderr_output = captured_stderr
    exit_status = captured_status_obj.exitstatus

    # JS-specific: Append stderr to result if execution failed and stderr has content
    if lang_config && lang_config[:error_handling] == :js_specific && exit_status != 0 && stderr_has_content?(stderr_output)
      result_output += "\nStderr:\n#{stderr_output.strip}"
    end
    return exit_status, result_output, stderr_output
  end

  def add_error_to_output(exit_status, lang_config, lang_key, result_output, stderr_output)
    warn "Code execution failed for language '#{lang_key}' with status #{exit_status}."
    warn "Stderr:\n#{stderr_output}" if stderr_has_content?(stderr_output)

    is_js_error_already_formatted = lang_config && lang_config[:error_handling] == :js_specific && result_output.include?("Stderr:")
    unless result_output.downcase.include?("error:") || is_js_error_already_formatted
      error_prefix = "Execution failed (status: #{exit_status})."
      error_prefix += " Stderr: #{stderr_output.strip}" if stderr_has_content?(stderr_output)
      result_output = "#{error_prefix}\n#{result_output}"
    end
    result_output
  end

  def execute_code_block(code_content, lang, temp_dir)
    captured_status_obj = nil

    lang_key = lang.downcase # Normalize lang input for lookup
    lang_config = SUPPORTED_LANGUAGES[lang_key]

    if lang_config
      exit_status = 0
      warn "Executing #{lang_key} code block..." # Generic description
      cmd_lambda = lang_config[:command]
      temp_file_suffix = lang_config[:temp_file_suffix]

      captured_stdout = nil
      if temp_file_suffix # Needs a temporary file. Use lang_key as prefix.
        Tempfile.create([ lang_key, temp_file_suffix ], temp_dir) do |temp_file|
          temp_file.write(code_content)
          temp_file.close
          # Pass temp_file.path. Lambda decides if it needs code_content directly.
          command_to_run, exec_options = cmd_lambda.call(code_content, temp_file.path)
          captured_stdout, _, captured_status_obj = Open3.capture3(command_to_run, **exec_options)
        end
      else # Direct command execution (e.g., psql that takes stdin)
        # Pass nil for temp_file_path. Lambda decides if it needs code_content.
        command_to_run, exec_options = cmd_lambda.call(code_content, nil)
        captured_stdout, captured_stderr, captured_status_obj = Open3.capture3(command_to_run, **exec_options)
      end
    else
      warn "Unsupported language: #{lang}"
      result_output = "ERROR: Unsupported language: #{lang}"
      exit_status = 1 # Indicate an error
      # captured_status_obj remains nil, so common assignments below won't run
    end

    if captured_status_obj
      exit_status, result_output, stderr_output = format_captured_output(captured_status_obj, captured_stderr, captured_stdout, lang_config)
    end

    if exit_status != 0
      result_output = add_error_to_output(exit_status, lang_config, lang_key, result_output, stderr_output)
    end
    result_output
  end
end
