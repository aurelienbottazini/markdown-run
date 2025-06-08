require_relative 'test_helper'
require_relative '../lib/language_configs'

class LanguageConfigsTest < Minitest::Test
        def test_js_config_command_returns_correct_format
    # Test that the command lambda returns the expected format
    command, options = JS_CONFIG[:command].call("console.log('test')", "/tmp/test.js")

    # Should return either bun or node command
    assert_includes ["bun /tmp/test.js", "node /tmp/test.js"], command
    assert_equal({}, options)
  end

    def test_js_config_uses_bun_when_available
    # Temporarily redefine system method to simulate bun being available
    original_system = Object.method(:system)
    Object.define_method(:system) do |command|
      if command == "command -v bun > /dev/null 2>&1"
        true
      else
        original_system.call(command)
      end
    end

    command, options = JS_CONFIG[:command].call("console.log('test')", "/tmp/test.js")

    assert_equal "bun /tmp/test.js", command
    assert_equal({}, options)
  ensure
    # Restore original system method
    Object.define_method(:system, original_system)
  end

  def test_js_config_falls_back_to_node_when_bun_unavailable
    # Temporarily redefine system method to simulate bun not being available
    original_system = Object.method(:system)
    Object.define_method(:system) do |command|
      if command == "command -v bun > /dev/null 2>&1"
        false
      else
        original_system.call(command)
      end
    end

    command, options = JS_CONFIG[:command].call("console.log('test')", "/tmp/test.js")

    assert_equal "node /tmp/test.js", command
    assert_equal({}, options)
  ensure
    # Restore original system method
    Object.define_method(:system, original_system)
  end

  def test_js_config_temp_file_suffix
    assert_equal ".js", JS_CONFIG[:temp_file_suffix]
  end

  def test_js_config_error_handling
    assert_equal :js_specific, JS_CONFIG[:error_handling]
  end

  def test_supported_languages_includes_js_aliases
    assert_equal JS_CONFIG, SUPPORTED_LANGUAGES["js"]
    assert_equal JS_CONFIG, SUPPORTED_LANGUAGES["javascript"]
  end

  def test_language_regex_part_includes_js_languages
    assert_includes LANGUAGE_REGEX_PART, "js"
    assert_includes LANGUAGE_REGEX_PART, "javascript"
  end

  def test_code_block_start_regex_matches_js
    assert_match CODE_BLOCK_START_REGEX, "```js"
    assert_match CODE_BLOCK_START_REGEX, "```javascript"
    assert_match CODE_BLOCK_START_REGEX, "```JS"
    assert_match CODE_BLOCK_START_REGEX, "```JavaScript"
  end

  # PSQL Configuration Tests
  def test_psql_config_when_available
    # Temporarily redefine system method to simulate psql being available
    original_system = Object.method(:system)
    Object.define_method(:system) do |command|
      if command == "command -v psql > /dev/null 2>&1"
        true
      else
        original_system.call(command)
      end
    end

    command, options = SUPPORTED_LANGUAGES["psql"][:command].call("SELECT 1;", nil)

    assert_equal "psql -A -t -X", command
    assert_equal({ stdin_data: "SELECT 1;" }, options)
  ensure
    # Restore original system method
    Object.define_method(:system, original_system)
  end

  def test_psql_config_when_unavailable
    # Temporarily redefine system method to simulate psql not being available
    original_system = Object.method(:system)
    Object.define_method(:system) do |command|
      if command == "command -v psql > /dev/null 2>&1"
        false
      else
        original_system.call(command)
      end
    end

    assert_raises(SystemExit) do
      SUPPORTED_LANGUAGES["psql"][:command].call("SELECT 1;", nil)
    end
  ensure
    # Restore original system method
    Object.define_method(:system, original_system)
  end

  def test_psql_config_with_explain
    # Temporarily redefine system method to simulate psql being available
    original_system = Object.method(:system)
    Object.define_method(:system) do |command|
      if command == "command -v psql > /dev/null 2>&1"
        true
      else
        original_system.call(command)
      end
    end

    command, options = SUPPORTED_LANGUAGES["psql"][:command].call("SELECT 1;", nil, nil, true)

    assert_equal "psql -A -t -X", command
    assert_equal({ stdin_data: "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) SELECT 1;" }, options)
  ensure
    # Restore original system method
    Object.define_method(:system, original_system)
  end

  # Ruby Configuration Tests
  def test_ruby_config_when_available
    # Temporarily redefine system method to simulate xmpfilter being available
    original_system = Object.method(:system)
    Object.define_method(:system) do |command|
      if command == "command -v xmpfilter > /dev/null 2>&1"
        true
      else
        original_system.call(command)
      end
    end

    command, options = SUPPORTED_LANGUAGES["ruby"][:command].call("puts 'test'", "/tmp/test.rb")

    assert_equal "xmpfilter /tmp/test.rb", command
    assert_equal({}, options)
  ensure
    # Restore original system method
    Object.define_method(:system, original_system)
  end

  def test_ruby_config_when_unavailable
    # Temporarily redefine system method to simulate xmpfilter not being available
    original_system = Object.method(:system)
    Object.define_method(:system) do |command|
      if command == "command -v xmpfilter > /dev/null 2>&1"
        false
      else
        original_system.call(command)
      end
    end

    assert_raises(SystemExit) do
      SUPPORTED_LANGUAGES["ruby"][:command].call("puts 'test'", "/tmp/test.rb")
    end
  ensure
    # Restore original system method
    Object.define_method(:system, original_system)
  end

  # Bash Configuration Tests
  def test_bash_config_when_available
    # Temporarily redefine system method to simulate bash being available
    original_system = Object.method(:system)
    Object.define_method(:system) do |command|
      if command == "command -v bash > /dev/null 2>&1"
        true
      else
        original_system.call(command)
      end
    end

    command, options = SUPPORTED_LANGUAGES["bash"][:command].call("echo 'test'", "/tmp/test.sh")

    assert_equal "bash /tmp/test.sh", command
    assert_equal({}, options)
  ensure
    # Restore original system method
    Object.define_method(:system, original_system)
  end

  def test_bash_config_when_unavailable
    # Temporarily redefine system method to simulate bash not being available
    original_system = Object.method(:system)
    Object.define_method(:system) do |command|
      if command == "command -v bash > /dev/null 2>&1"
        false
      else
        original_system.call(command)
      end
    end

    assert_raises(SystemExit) do
      SUPPORTED_LANGUAGES["bash"][:command].call("echo 'test'", "/tmp/test.sh")
    end
  ensure
    # Restore original system method
    Object.define_method(:system, original_system)
  end

  # Zsh Configuration Tests
  def test_zsh_config_when_available
    # Temporarily redefine system method to simulate zsh being available
    original_system = Object.method(:system)
    Object.define_method(:system) do |command|
      if command == "command -v zsh > /dev/null 2>&1"
        true
      else
        original_system.call(command)
      end
    end

    command, options = SUPPORTED_LANGUAGES["zsh"][:command].call("echo 'test'", "/tmp/test.zsh")

    assert_equal "zsh /tmp/test.zsh", command
    assert_equal({}, options)
  ensure
    # Restore original system method
    Object.define_method(:system, original_system)
  end

  def test_zsh_config_when_unavailable
    # Temporarily redefine system method to simulate zsh not being available
    original_system = Object.method(:system)
    Object.define_method(:system) do |command|
      if command == "command -v zsh > /dev/null 2>&1"
        false
      else
        original_system.call(command)
      end
    end

    assert_raises(SystemExit) do
      SUPPORTED_LANGUAGES["zsh"][:command].call("echo 'test'", "/tmp/test.zsh")
    end
  ensure
    # Restore original system method
    Object.define_method(:system, original_system)
  end

  # Sh Configuration Tests
  def test_sh_config_when_available
    # Temporarily redefine system method to simulate sh being available
    original_system = Object.method(:system)
    Object.define_method(:system) do |command|
      if command == "command -v sh > /dev/null 2>&1"
        true
      else
        original_system.call(command)
      end
    end

    command, options = SUPPORTED_LANGUAGES["sh"][:command].call("echo 'test'", "/tmp/test.sh")

    assert_equal "sh /tmp/test.sh", command
    assert_equal({}, options)
  ensure
    # Restore original system method
    Object.define_method(:system, original_system)
  end

  def test_sh_config_when_unavailable
    # Temporarily redefine system method to simulate sh not being available
    original_system = Object.method(:system)
    Object.define_method(:system) do |command|
      if command == "command -v sh > /dev/null 2>&1"
        false
      else
        original_system.call(command)
      end
    end

    assert_raises(SystemExit) do
      SUPPORTED_LANGUAGES["sh"][:command].call("echo 'test'", "/tmp/test.sh")
    end
  ensure
    # Restore original system method
    Object.define_method(:system, original_system)
  end

  # Mermaid Configuration Tests
  def test_mermaid_config_when_available
    # Temporarily redefine system method to simulate mmdc being available
    original_system = Object.method(:system)
    Object.define_method(:system) do |command|
      if command == "command -v mmdc > /dev/null 2>&1"
        true
      else
        original_system.call(command)
      end
    end

    command, options = SUPPORTED_LANGUAGES["mermaid"][:command].call("graph TD; A-->B", "/tmp/test.mmd")

    assert_includes command, "mmdc -i /tmp/test.mmd -o"
    assert_includes options.keys, :output_path
  ensure
    # Restore original system method
    Object.define_method(:system, original_system)
  end

  def test_mermaid_config_when_unavailable
    # Temporarily redefine system method to simulate mmdc not being available
    original_system = Object.method(:system)
    Object.define_method(:system) do |command|
      if command == "command -v mmdc > /dev/null 2>&1"
        false
      else
        original_system.call(command)
      end
    end

    assert_raises(SystemExit) do
      SUPPORTED_LANGUAGES["mermaid"][:command].call("graph TD; A-->B", "/tmp/test.mmd")
    end
  ensure
    # Restore original system method
    Object.define_method(:system, original_system)
  end

  # Test configuration properties for all languages
  def test_all_supported_languages_have_command
    SUPPORTED_LANGUAGES.each do |lang, config|
      assert config.key?(:command), "Language #{lang} missing :command"
      assert config[:command].respond_to?(:call), "Language #{lang} command is not callable"
    end
  end

  def test_sqlite_config_properties
    assert_equal ".db", SQLITE_CONFIG[:temp_file_suffix]
    assert SQLITE_CONFIG[:command].respond_to?(:call)

    command, options = SQLITE_CONFIG[:command].call("SELECT 1;", "/tmp/test.db")
    assert_equal "sqlite3 /tmp/test.db", command
    assert_equal({ stdin_data: "SELECT 1;" }, options)
  end
end