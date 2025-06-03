require_relative "language_configs"

class CodeBlockParser
  # Code block header pattern: ```language options
  CODE_BLOCK_START_PATTERN = /^```(\w+)(?:\s+(.*))?$/i
  RUBY_RESULT_BLOCK_PATTERN = /^```ruby\s+RESULT$/i
  BLOCK_END_PATTERN = "```"

  def initialize(frontmatter_parser)
    @frontmatter_parser = frontmatter_parser
  end

  def parse_code_block_header(line)
    match_data = line.match(CODE_BLOCK_START_PATTERN)
    return nil unless match_data

    lang = match_data[1].downcase
    options_string = match_data[2]
    resolved_lang = resolve_language(lang)

    {
      original_lang: lang,
      resolved_lang: resolved_lang,
      options_string: options_string,
      is_supported: SUPPORTED_LANGUAGES.key?(resolved_lang)
    }
  end

  def is_ruby_result_block?(line)
    line.match?(RUBY_RESULT_BLOCK_PATTERN)
  end

  def is_block_end?(line)
    line.strip == BLOCK_END_PATTERN
  end

  def parse_run_option(options_string, language = nil)
    default_value = @frontmatter_parser.get_default_value("run", language, true)
    parse_boolean_option(options_string, "run", default_value)
  end

  def parse_rerun_option(options_string, language = nil)
    default_value = @frontmatter_parser.get_default_value("rerun", language, false)
    parse_boolean_option(options_string, "rerun", default_value)
  end

  def parse_explain_option(options_string, language = nil)
    default_value = @frontmatter_parser.get_default_value("explain", language, false)
    parse_boolean_option(options_string, "explain", default_value)
  end

  def parse_result_option(options_string, language = nil)
    default_value = @frontmatter_parser.get_default_value("result", language, true)
    parse_boolean_option(options_string, "result", default_value)
  end

  private

  def resolve_language(lang)
    @frontmatter_parser.resolve_language(lang)
  end

  def parse_boolean_option(options_string, option_name, default_value)
    return default_value unless options_string

    # First, check for explicit option=true/false assignments (highest priority)
    explicit_match = options_string.match(/#{option_name}\s*=\s*(true|false)/i)
    if explicit_match
      return explicit_match[1].downcase == "true"
    end

    # If no explicit assignment, check for standalone option (e.g., "rerun")
    standalone_match = options_string.match(/\b#{option_name}\b(?!\s*=)/i)
    if standalone_match
      return true
    end

    # If neither found, return default value
    default_value
  end
end
