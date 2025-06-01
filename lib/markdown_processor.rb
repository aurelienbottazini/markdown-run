require_relative "language_configs"
require_relative "frontmatter_parser"
require_relative "code_block_parser"
require_relative "code_executor"
require_relative "execution_decider"
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
    @code_block_parser = CodeBlockParser.new(@frontmatter_parser)
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
    @code_block_parser.is_block_end?(line)
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
    @code_block_parser.parse_rerun_option(options_string)
  end

  def parse_run_option(options_string)
    @code_block_parser.parse_run_option(options_string)
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
    if @code_block_parser.is_ruby_result_block?(current_line)
      handle_existing_ruby_result_block(current_line, file_enum)
    else
      parsed_header = @code_block_parser.parse_code_block_header(current_line)
      if parsed_header && parsed_header[:is_supported]
        start_code_block(current_line, parsed_header[:original_lang], parsed_header[:options_string])
      else
        @output_lines << current_line
      end
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
    decider = ExecutionDecider.new(@current_block_run, @current_block_rerun, @current_block_lang)
    decision = decider.decide(file_enum, method(:result_block_regex))

    # Handle the consume_existing flag for rerun scenarios
    if decision[:consume_existing]
      consume_existing_result_block(file_enum, decision[:consumed_lines])
    end

    decision
  end

  def execute_and_add_result(blank_line_before_new_result)
    @output_lines << blank_line_before_new_result if blank_line_before_new_result

    if has_content?(@current_code_content)
      result_output = CodeExecutor.execute(@current_code_content, @current_block_lang, @temp_dir)
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
end
