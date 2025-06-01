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

  def parse_run_option(options_string)
    parse_boolean_option(options_string, "run", true)
  end

  def parse_rerun_option(options_string)
    parse_boolean_option(options_string, "rerun", false)
  end

  private

  def resolve_language(lang)
    @frontmatter_parser.resolve_language(lang)
  end

  def parse_boolean_option(options_string, option_name, default_value)
    return default_value unless options_string

    # Match option=true or option=false
    match = options_string.match(/#{option_name}\s*=\s*(true|false)/i)
    return default_value unless match

    match[1].downcase == "true"
  end
end
