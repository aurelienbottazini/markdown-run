JS_CONFIG = {
  command: ->(_code_content, temp_file_path) {
    # Check if bun is available
    bun_exists = system("command -v bun > /dev/null 2>&1")
    if bun_exists
      [ "bun #{temp_file_path}", {} ]
    else
      # Fallback to node if bun is not available
      [ "node #{temp_file_path}", {} ]
    end
  },
  temp_file_suffix: ".js",
  error_handling: :js_specific # For specific stderr appending on error
}.freeze

SQLITE_CONFIG = {
  command: ->(code_content, temp_file_path) { [ "sqlite3 #{temp_file_path}", { stdin_data: code_content } ] },
  temp_file_suffix: ".db" # Temp file is the database
}.freeze

SUPPORTED_LANGUAGES = {
  "psql" => {
    command: ->(code_content, _temp_file_path) {
      psql_exists = system("command -v psql > /dev/null 2>&1")
      unless psql_exists
        abort "Error: psql command not found. Please install PostgreSQL or ensure psql is in your PATH."
      end
      [ "psql -A -t -X", { stdin_data: code_content } ]
    }
  },
  "ruby" => {
    command: ->(_code_content, temp_file_path) {
      xmpfilter_exists = system("command -v xmpfilter > /dev/null 2>&1")
      unless xmpfilter_exists
        abort "Error: xmpfilter command not found. Please install xmpfilter or ensure it is in your PATH."
      end
      [ "xmpfilter #{temp_file_path}", {} ]
    },
    temp_file_suffix: ".rb",
    result_block_type: "ruby" # For special '```ruby RESULT' blocks
  },
  "js" => JS_CONFIG,
  "javascript" => JS_CONFIG, # Alias for js
  "sql" => SQLITE_CONFIG,
  "sqlite" => SQLITE_CONFIG,
  "sqlite3" => SQLITE_CONFIG, # Alias for sqlite
  "bash" => {
    command: ->(_code_content, temp_file_path) {
      bash_exists = system("command -v bash > /dev/null 2>&1")
      unless bash_exists
        abort "Error: bash command not found. Please ensure bash is in your PATH."
      end
      [ "bash #{temp_file_path}", {} ]
    },
    temp_file_suffix: ".sh"
  },
  "zsh" => {
    command: ->(_code_content, temp_file_path) {
      zsh_exists = system("command -v zsh > /dev/null 2>&1")
      unless zsh_exists
        abort "Error: zsh command not found. Please ensure zsh is in your PATH."
      end
      [ "zsh #{temp_file_path}", {} ]
    },
    temp_file_suffix: ".zsh"
  },
  "sh" => {
    command: ->(_code_content, temp_file_path) {
      sh_exists = system("command -v sh > /dev/null 2>&1")
      unless sh_exists
        abort "Error: sh command not found. Please ensure sh is in your PATH."
      end
      [ "sh #{temp_file_path}", {} ]
    },
    temp_file_suffix: ".sh"
  },
  "mermaid" => {
    command: ->(code_content, temp_file_path) {
      mmdc_exists = system("command -v mmdc > /dev/null 2>&1")
      unless mmdc_exists
        abort "Error: mmdc command not found. Please install @mermaid-js/mermaid-cli: npm install -g @mermaid-js/mermaid-cli"
      end

      # Generate SVG output file path
      input_dir = File.dirname(temp_file_path)
      base_name = File.basename(temp_file_path, ".*")
      output_path = File.join(input_dir, "#{base_name}.svg")

      [ "mmdc -i #{temp_file_path} -o #{output_path}", { output_path: output_path } ]
    },
    temp_file_suffix: ".mmd",
    result_handling: :mermaid_svg # Special handling for SVG generation
  }
}.freeze

LANGUAGE_REGEX_PART = SUPPORTED_LANGUAGES.keys.map { |lang| Regexp.escape(lang) }.join("|").freeze
CODE_BLOCK_START_REGEX = /^```(#{LANGUAGE_REGEX_PART})$/i
