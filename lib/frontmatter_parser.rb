require "yaml"
require_relative "enum_helper"

class FrontmatterParser
  include EnumHelper

  def initialize
    @aliases = {}
  end

  attr_reader :aliases

  def parse_frontmatter(file_enum, output_lines)
    first_line = peek_next_line(file_enum)
    return unless first_line&.strip == "---"

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

    return if frontmatter_lines.empty?

    begin
      frontmatter = YAML.safe_load(frontmatter_lines.join)
      extract_aliases(frontmatter) if frontmatter.is_a?(Hash)
    rescue YAML::SyntaxError => e
      warn "Warning: Invalid YAML frontmatter: #{e.message}"
    end
  end

  def resolve_language(lang)
    @aliases[lang] || lang
  end

  private

  def extract_aliases(frontmatter)
    markdown_run_config = frontmatter["markdown-run"]
    return unless markdown_run_config.is_a?(Hash)

    aliases = markdown_run_config["alias"]
    return unless aliases.is_a?(Array)

    aliases.each do |alias_config|
      next unless alias_config.is_a?(Hash)

      alias_config.each do |alias_name, target_lang|
        @aliases[alias_name.to_s] = target_lang.to_s
      end
    end
  end
end
