require_relative 'test_helper'
require_relative '../lib/language_configs'

class LanguageConfigsTest < Minitest::Test
  def test_js_config_command_returns_correct_format
    # Test that the command lambda returns the expected format
    command, options = JS_CONFIG[:command].call(**{ code_content: "console.log('test')", temp_file_path: "/tmp/test.js" })

    # Should return either bun or node command
    assert_includes ["bun /tmp/test.js", "node /tmp/test.js"], command
    assert_equal({}, options)
  end

  def test_js_config_uses_bun_when_available
    # Temporarily stub system method to simulate bun being available
    stub_system = ->(command) {
      command == "command -v bun > /dev/null 2>&1"
    }

    TOPLEVEL_BINDING.eval('self').stub(:system, stub_system) do
      command, options = JS_CONFIG[:command].call(**{ code_content: "console.log('test')", temp_file_path: "/tmp/test.js" })

      assert_equal "bun /tmp/test.js", command
      assert_equal({}, options)
    end
  end

  def test_js_config_falls_back_to_node_when_bun_unavailable
    # Temporarily stub system method to simulate bun not being available
    stub_system = ->(command) {
      false  # bun not available, should fallback to node
    }

    TOPLEVEL_BINDING.eval('self').stub(:system, stub_system) do
      command, options = JS_CONFIG[:command].call(**{ code_content: "console.log('test')", temp_file_path: "/tmp/test.js" })

      assert_equal "node /tmp/test.js", command
      assert_equal({}, options)
    end
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
    # Temporarily stub system method to simulate psql being available
    stub_system = ->(command) {
      command == "command -v psql > /dev/null 2>&1"
    }

    TOPLEVEL_BINDING.eval("self").stub(:system, stub_system) do
      command, options = SUPPORTED_LANGUAGES["psql"][:command].call(**{ code_content: "SELECT 1;" })

      assert_equal "psql -A -t -X", command
      assert_equal({ stdin_data: "SELECT 1;" }, options)
    end
  end

  def test_psql_config_when_unavailable
    # Temporarily stub system method to simulate psql not being available
    stub_system = ->(command) {
      false  # psql not available
    }

    TOPLEVEL_BINDING.eval("self").stub(:system, stub_system) do
      assert_raises(SystemExit) do
        SUPPORTED_LANGUAGES["psql"][:command].call(**{ code_content: "SELECT 1;" })
      end
    end
  end

  def test_psql_config_with_explain
    # Temporarily stub system method to simulate psql being available
    stub_system = ->(command) {
      command == "command -v psql > /dev/null 2>&1"
    }

    TOPLEVEL_BINDING.eval("self").stub(:system, stub_system) do
      command, options = SUPPORTED_LANGUAGES["psql"][:command].call(**{ code_content: "SELECT 1;", explain: true })

      assert_equal "psql -A -t -X", command
      assert_equal({ stdin_data: "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) SELECT 1;" }, options)
    end
  end

  # Ruby Configuration Tests
  def test_ruby_config_when_available
    # Temporarily stub system method to simulate xmpfilter being available
    stub_system = ->(command) {
      command == "command -v xmpfilter > /dev/null 2>&1"
    }

    TOPLEVEL_BINDING.eval("self").stub(:system, stub_system) do
      command, options = SUPPORTED_LANGUAGES["ruby"][:command].call(**{ temp_file_path: "/tmp/test.rb" })

      assert_equal "xmpfilter /tmp/test.rb", command
      assert_equal({}, options)
    end
  end

  def test_ruby_config_when_unavailable
    # Temporarily stub system method to simulate xmpfilter not being available
    stub_system = ->(command) {
      false  # xmpfilter not available
    }

    TOPLEVEL_BINDING.eval("self").stub(:system, stub_system) do
      assert_raises(SystemExit) do
        SUPPORTED_LANGUAGES["ruby"][:command].call(**{ temp_file_path: "/tmp/test.rb" })
      end
    end
  end

  # Bash Configuration Tests
  def test_bash_config_when_available
    # Temporarily stub system method to simulate bash being available
    stub_system = ->(command) {
      command == "command -v bash > /dev/null 2>&1"
    }

    TOPLEVEL_BINDING.eval("self").stub(:system, stub_system) do
      command, options = SUPPORTED_LANGUAGES["bash"][:command].call(**{ temp_file_path: "/tmp/test.sh" })

      assert_equal "bash /tmp/test.sh", command
      assert_equal({}, options)
    end
  end

  def test_bash_config_when_unavailable
    # Temporarily stub system method to simulate bash not being available
    stub_system = ->(command) {
      false  # bash not available
    }

    TOPLEVEL_BINDING.eval("self").stub(:system, stub_system) do
      assert_raises(SystemExit) do
        SUPPORTED_LANGUAGES["bash"][:command].call(**{ temp_file_path: "/tmp/test.sh" })
      end
    end
  end

  # Zsh Configuration Tests
  def test_zsh_config_when_available
    # Temporarily stub system method to simulate zsh being available
    stub_system = ->(command) {
      command == "command -v zsh > /dev/null 2>&1"
    }

    TOPLEVEL_BINDING.eval("self").stub(:system, stub_system) do
      command, options = SUPPORTED_LANGUAGES["zsh"][:command].call(**{ temp_file_path: "/tmp/test.zsh" })

      assert_equal "zsh /tmp/test.zsh", command
      assert_equal({}, options)
    end
  end

  def test_zsh_config_when_unavailable
    # Temporarily stub system method to simulate zsh not being available
    stub_system = ->(command) {
      false  # zsh not available
    }

    TOPLEVEL_BINDING.eval("self").stub(:system, stub_system) do
      assert_raises(SystemExit) do
        SUPPORTED_LANGUAGES["zsh"][:command].call(**{ temp_file_path: "/tmp/test.zsh" })
      end
    end
  end

  # Sh Configuration Tests
  def test_sh_config_when_available
    # Temporarily stub system method to simulate sh being available
    stub_system = ->(command) {
      command == "command -v sh > /dev/null 2>&1"
    }

    TOPLEVEL_BINDING.eval("self").stub(:system, stub_system) do
      command, options = SUPPORTED_LANGUAGES["sh"][:command].call(**{ temp_file_path: "/tmp/test.sh" })

      assert_equal "sh /tmp/test.sh", command
      assert_equal({}, options)
    end
  end

  def test_sh_config_when_unavailable
    # Temporarily stub system method to simulate sh not being available
    stub_system = ->(command) {
      false  # sh not available
    }

    TOPLEVEL_BINDING.eval("self").stub(:system, stub_system) do
      assert_raises(SystemExit) do
        SUPPORTED_LANGUAGES["sh"][:command].call(**{ temp_file_path: "/tmp/test.sh" })
      end
    end
  end

  # Mermaid Configuration Tests
  def test_mermaid_config_when_available
    # Temporarily stub system method to simulate mmdc being available
    stub_system = ->(command) {
      command == "command -v mmdc > /dev/null 2>&1"
    }

    TOPLEVEL_BINDING.eval("self").stub(:system, stub_system) do
      command, options = SUPPORTED_LANGUAGES["mermaid"][:command].call(**{ code_content: "graph TD; A-->B", temp_file_path: "/tmp/test.mmd" })

      assert_equal "mmdc -i /tmp/test.mmd -o /tmp/test.svg", command
      assert_equal({ output_path: "/tmp/test.svg" }, options)
    end
  end

  def test_mermaid_config_when_unavailable
    # Temporarily stub system method to simulate mmdc not being available
    stub_system = ->(command) {
      false  # mmdc not available
    }

    TOPLEVEL_BINDING.eval("self").stub(:system, stub_system) do
      assert_raises(SystemExit) do
        SUPPORTED_LANGUAGES["mermaid"][:command].call(**{ code_content: "graph TD; A-->B", temp_file_path: "/tmp/test.mmd" })
      end
    end
  end

  def test_all_supported_languages_have_command
    SUPPORTED_LANGUAGES.each do |lang, config|
      assert_respond_to config[:command], :call, "Language #{lang} should have a callable command"
    end
  end

  def test_sqlite_config_properties
    assert_equal ".db", SQLITE_CONFIG[:temp_file_suffix]

    command, options = SQLITE_CONFIG[:command].call(**{ code_content: "SELECT 1;", temp_file_path: "/tmp/test.db" })
    assert_equal "sqlite3 /tmp/test.db", command
    assert_equal({ stdin_data: "SELECT 1;" }, options)
  end
end