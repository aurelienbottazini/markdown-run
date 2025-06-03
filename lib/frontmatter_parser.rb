require "yaml"
require_relative "enum_helper"

class FrontmatterParser
  include EnumHelper

  def initialize
    @aliases = {}
    @defaults = {}
    @language_defaults = {}
  end

  attr_reader :aliases, :defaults, :language_defaults

  def parse_frontmatter(file_enum, output_lines)
    first_line = peek_next_line(file_enum)
    return unless first_line&.strip == "---"

    frontmatter_lines = collect_frontmatter_lines(file_enum, output_lines)
    process_frontmatter_content(frontmatter_lines) unless frontmatter_lines.empty?
  end

  def resolve_language(lang)
    @aliases[lang] || lang
  end

  def get_default_value(option_name, language, fallback_default)
    # Priority order:
    # 1. Language-specific defaults (e.g., psql: { explain: true })
    # 2. Global defaults (e.g., defaults: { rerun: true })
    # 3. Fallback default (hardcoded in the application)

    # Check language-specific defaults first
    if @language_defaults[language] && @language_defaults[language].key?(option_name)
      return @language_defaults[language][option_name]
    end

    # Check global defaults
    if @defaults.key?(option_name)
      return @defaults[option_name]
    end

    # Return fallback default
    fallback_default
  end

  private

  def collect_frontmatter_lines(file_enum, output_lines)
    # Consume the opening ---
    output_lines << file_enum.next
    frontmatter_lines = []

    loop do
      line = get_next_line(file_enum)
      break unless line

      if line.strip == "---"
        output_lines << line
        break
      end

      frontmatter_lines << line
      output_lines << line
    end

    frontmatter_lines
  end

  def process_frontmatter_content(frontmatter_lines)
    begin
      frontmatter = YAML.safe_load(frontmatter_lines.join)
      extract_aliases(frontmatter) if frontmatter.is_a?(Hash)
    rescue YAML::SyntaxError => e
      warn "Warning: Invalid YAML frontmatter: #{e.message}"
    end
  end

  def extract_aliases(frontmatter)
    markdown_run_config = frontmatter["markdown-run"]
    return unless markdown_run_config.is_a?(Hash)

    # Extract aliases
    aliases = markdown_run_config["alias"]
    if aliases.is_a?(Array)
      aliases.each do |alias_config|
        next unless alias_config.is_a?(Hash)

        alias_config.each do |alias_name, target_lang|
          @aliases[alias_name.to_s] = target_lang.to_s
        end
      end
    end

    # Extract defaults
    defaults = markdown_run_config["defaults"]
    if defaults.is_a?(Hash)
      defaults.each do |option_name, option_value|
        @defaults[option_name.to_s] = option_value
      end
    end

    # Extract language-specific defaults
    markdown_run_config.each do |key, value|
      next if ["alias", "defaults"].include?(key)
      next unless value.is_a?(Hash)

      @language_defaults[key.to_s] = {}
      value.each do |option_name, option_value|
        @language_defaults[key.to_s][option_name.to_s] = option_value
      end
    end
  end
end
