require_relative "language_configs"
require_relative "frontmatter_parser"
require_relative "code_block_parser"
require_relative "code_executor"
require_relative "execution_decider"
require_relative "enum_helper"
require_relative "dalibo_helper"
require_relative "code_block_helper"
require_relative "result_helper"

class MarkdownProcessor
  include EnumHelper
  include DaliboHelper
  include CodeBlockHelper
  include ResultHelper

  def initialize(temp_dir, input_file_path = nil)
    @temp_dir = temp_dir
    @input_file_path = input_file_path
    @output_lines = []
    reset_code_block_state

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

  def is_block_end?(line)
    @code_block_parser.is_block_end?(line)
  end

  def has_content?(content)
    !content.strip.empty?
  end

  def line_matches_pattern?(line, pattern)
    line && line.match?(pattern)
  end

  def is_blank_line?(line)
    line && line.strip == ""
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
end
