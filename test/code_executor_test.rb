require_relative 'test_helper'
require_relative '../lib/code_executor'
require 'tempfile'
require 'fileutils'
require 'net/http'

class CodeExecutorTest < Minitest::Test
  include MarkdownTestHelper

  def setup
    super
    @executor = CodeExecutor.new
    @temp_dir = Dir.mktmpdir("code_executor_tests")
  end

  def teardown
    super
    FileUtils.remove_entry @temp_dir if @temp_dir && Dir.exist?(@temp_dir)
  end

  def test_class_method_execute
    # Test the class method that creates a new instance
    result = CodeExecutor.execute("puts 'test'", "unsupported_lang", @temp_dir)
    assert_includes result, "ERROR: Unsupported language"
  end

  def test_unsupported_language_handling
    # Test handling of unsupported languages (lines 29-31)
    result = @executor.execute("some code", "unsupported_lang", @temp_dir)

    assert_equal "ERROR: Unsupported language: unsupported_lang", result
  end

  def test_execute_direct_command_sqlite
    # Test direct command execution without temp files (lines 67-69)
    # SQLite uses direct command execution with stdin
    code = "SELECT 1;"
    result = @executor.execute(code, "sqlite", @temp_dir)

    # Should execute successfully (1 is the expected output)
    assert_includes result, "1"
  end

  def test_stderr_has_content_detection
    # Test the stderr_has_content? method (line 25-26 and 120)
    assert @executor.send(:stderr_has_content?, "Error: something went wrong")
    assert @executor.send(:stderr_has_content?, "   Error with spaces   ")
    refute @executor.send(:stderr_has_content?, "")
    refute @executor.send(:stderr_has_content?, "   ")
    refute @executor.send(:stderr_has_content?, nil)
  end

  def test_javascript_error_handling_with_stderr
    # Test JS-specific error handling when stderr has content (lines ~100)
    # We need to simulate a JavaScript execution that fails with stderr

    # Create a mock result that simulates failed JS execution
    mock_result = {
      stdout: "console output",
      stderr: "ReferenceError: undefined variable",
      status: OpenStruct.new(exitstatus: 1)
    }

    # Create a mock JS language config
    js_config = { error_handling: :js_specific }

    exit_status, result_output, stderr_output = @executor.send(:format_captured_output, mock_result, js_config)

    assert_equal 1, exit_status
    assert_includes result_output, "Stderr:"
    assert_includes result_output, "ReferenceError"
  end

  def test_add_error_to_output_with_stderr
    # Test error formatting when stderr has content (lines 106-119)
    lang_config = {}
    result_output = "some output"
    stderr_output = "Error message"

    result = @executor.send(:add_error_to_output, 1, lang_config, "ruby", result_output, stderr_output)

    assert_includes result, "Execution failed (status: 1)"
    assert_includes result, "Error message"
  end

  def test_add_error_to_output_js_already_formatted
    # Test that JS errors don't get double-formatted (lines 111-115)
    js_config = { error_handling: :js_specific }
    result_output = "output\nStderr:\nSome error"  # Already formatted
    stderr_output = "Some error"

    result = @executor.send(:add_error_to_output, 1, js_config, "js", result_output, stderr_output)

    # Should not add another "Execution failed" prefix
    refute_includes result, "Execution failed"
    assert_includes result, "Stderr:"
  end

  def test_add_error_to_output_when_error_already_present
    # Test when result already contains "error:" (lines 111-115)
    result_output = "Error: something already went wrong"

    result = @executor.send(:add_error_to_output, 1, {}, "ruby", result_output, "")

    # Should not add another error prefix
    assert_equal "Error: something already went wrong", result
  end

  def test_handle_mermaid_svg_result_file_not_found
    # Test Mermaid SVG handling when file doesn't exist (lines ~125-128)
    mock_result = {
      output_path: "/nonexistent/path/diagram.svg"
    }

    result = @executor.send(:handle_mermaid_svg_result, mock_result, "mermaid")

    assert_equal "Error: SVG file not generated", result
  end

  def test_handle_mermaid_svg_result_no_output_path
    # Test Mermaid SVG handling when no output path provided
    mock_result = {}

    result = @executor.send(:handle_mermaid_svg_result, mock_result, "mermaid")

    assert_equal "Error: SVG file not generated", result
  end

  def test_handle_mermaid_svg_result_success_subdirectory
    # Test successful Mermaid SVG handling with subdirectory (lines ~130-140)
    # Create a mock SVG file in a subdirectory structure
    test_md_dir = File.join(@temp_dir, "test_md")
    Dir.mkdir(test_md_dir)
    svg_file = File.join(test_md_dir, "diagram.svg")
    File.write(svg_file, "<svg>test</svg>")

    mock_result = {
      output_path: svg_file
    }

    result = @executor.send(:handle_mermaid_svg_result, mock_result, "mermaid")

    assert_includes result, "![Mermaid Diagram]"
    assert_includes result, "test_md/diagram.svg"
  end

    def test_handle_mermaid_svg_result_success_same_directory
    # Test Mermaid SVG handling in same directory (fallback behavior)
    svg_file = File.join(@temp_dir, "diagram.svg")
    File.write(svg_file, "<svg>test</svg>")

    mock_result = {
      output_path: svg_file
    }

    result = @executor.send(:handle_mermaid_svg_result, mock_result, "mermaid")

    assert_includes result, "![Mermaid Diagram]"
    assert_includes result, "diagram.svg"
    # The result might include the temp directory structure, so just check it ends with the filename
    assert result.end_with?("diagram.svg)")
  end

  def test_handle_psql_explain_result_valid_json
    # Test PSQL explain result handling with valid JSON (lines ~160-175)
    valid_json = '[{"Plan": {"Node Type": "Seq Scan"}}]'

    # Mock the submit_plan_to_dalibo method to return a URL
    @executor.stub(:submit_plan_to_dalibo, "https://explain.dalibo.com/plan/123") do
      result = @executor.send(:handle_psql_explain_result, valid_json)

      assert_includes result, "DALIBO_LINK:https://explain.dalibo.com/plan/123"
      assert_includes result, valid_json
    end
  end

  def test_handle_psql_explain_result_failed_submission
    # Test when Dalibo submission fails (lines ~176-180)
    valid_json = '[{"Plan": {"Node Type": "Seq Scan"}}]'

    # Mock the submit_plan_to_dalibo method to return nil (failure)
    @executor.stub(:submit_plan_to_dalibo, nil) do
      result = @executor.send(:handle_psql_explain_result, valid_json)

      # Should return original output when submission fails
      assert_equal valid_json, result
    end
  end

  def test_handle_psql_explain_result_invalid_json
    # Test PSQL explain result with invalid JSON (lines ~181-184)
    invalid_json = "not json at all"

    result = @executor.send(:handle_psql_explain_result, invalid_json)

    # Should return original output when JSON parsing fails
    assert_equal invalid_json, result
  end

  def test_handle_psql_flamegraph_result_with_dalibo_prefix
    # Test flamegraph handling when result has Dalibo prefix (lines ~190-215)
    dalibo_prefixed_result = "DALIBO_LINK:https://explain.dalibo.com/plan/123\n[{\"Plan\": {\"Node Type\": \"Seq Scan\"}}]"

    # Mock the PostgreSQLFlameGraphSVG class
    mock_generator = Minitest::Mock.new
    mock_generator.expect(:generate_svg, "<svg>flamegraph</svg>")

    # We need to handle the require_relative and class instantiation
    original_require = method(:require_relative)
    self.stub(:require_relative, ->(path) {
      return true if path == 'pg_flamegraph_svg'
      original_require.call(path)
    }) do
      # Mock the class constant
      Object.const_set(:PostgreSQLFlameGraphSVG, Class.new do
        def initialize(json); end
        def generate_svg; "<svg>flamegraph</svg>"; end
      end) unless Object.const_defined?(:PostgreSQLFlameGraphSVG)

      result = @executor.send(:handle_psql_flamegraph_result, dalibo_prefixed_result, "test.md")

      assert_includes result, "DALIBO_LINK:https://explain.dalibo.com/plan/123"
      assert_includes result, "FLAMEGRAPH_LINK:"
    end
  end

  def test_handle_psql_flamegraph_result_without_input_file
    # Test flamegraph handling without input file path (lines ~230-235)
    valid_json = '[{"Plan": {"Node Type": "Seq Scan"}}]'

    # Mock the PostgreSQLFlameGraphSVG class
    Object.const_set(:PostgreSQLFlameGraphSVG, Class.new do
      def initialize(json); end
      def generate_svg; "<svg>flamegraph</svg>"; end
    end) unless Object.const_defined?(:PostgreSQLFlameGraphSVG)

    result = @executor.send(:handle_psql_flamegraph_result, valid_json, nil)

    assert_includes result, "FLAMEGRAPH_LINK:"
    assert_includes result, "pg-flamegraph-"
  end

  def test_handle_psql_flamegraph_result_json_parse_error
    # Test flamegraph handling with JSON parse error (lines ~250-252)
    invalid_json = "not json"

    result = @executor.send(:handle_psql_flamegraph_result, invalid_json, nil)

    # Should return original result when JSON parsing fails
    assert_equal invalid_json, result
  end

  def test_submit_plan_to_dalibo_success
    # Test successful Dalibo submission (lines ~253-281)
    plan_json = '{"Plan": "test"}'

    # Mock the HTTP request
    mock_response = Minitest::Mock.new
    mock_response.expect(:is_a?, true, [Net::HTTPRedirection])
    mock_response.expect(:'[]', '/plan/123', ['location'])

    mock_http = Minitest::Mock.new
    mock_http.expect(:use_ssl=, nil, [true])
    mock_http.expect(:read_timeout=, nil, [10])
    mock_http.expect(:request, mock_response, [Net::HTTP::Post])

    Net::HTTP.stub(:new, mock_http) do
      result = @executor.send(:submit_plan_to_dalibo, plan_json)
      assert_equal "https://explain.dalibo.com/plan/123", result
    end

    mock_response.verify
    mock_http.verify
  end

  def test_submit_plan_to_dalibo_absolute_location
    # Test Dalibo submission with absolute location URL
    plan_json = '{"Plan": "test"}'

    mock_response = Minitest::Mock.new
    mock_response.expect(:is_a?, true, [Net::HTTPRedirection])
    mock_response.expect(:'[]', 'https://explain.dalibo.com/plan/456', ['location'])

    mock_http = Minitest::Mock.new
    mock_http.expect(:use_ssl=, nil, [true])
    mock_http.expect(:read_timeout=, nil, [10])
    mock_http.expect(:request, mock_response, [Net::HTTP::Post])

    Net::HTTP.stub(:new, mock_http) do
      result = @executor.send(:submit_plan_to_dalibo, plan_json)
      assert_equal "https://explain.dalibo.com/plan/456", result
    end

    mock_response.verify
    mock_http.verify
  end

  def test_submit_plan_to_dalibo_no_location
    # Test Dalibo submission when response has no location header (lines ~276-280)
    plan_json = '{"Plan": "test"}'

    mock_response = Minitest::Mock.new
    mock_response.expect(:is_a?, true, [Net::HTTPRedirection])
    mock_response.expect(:'[]', nil, ['location'])

    mock_http = Minitest::Mock.new
    mock_http.expect(:use_ssl=, nil, [true])
    mock_http.expect(:read_timeout=, nil, [10])
    mock_http.expect(:request, mock_response, [Net::HTTP::Post])

    Net::HTTP.stub(:new, mock_http) do
      result = @executor.send(:submit_plan_to_dalibo, plan_json)
      assert_nil result
    end

    mock_response.verify
    mock_http.verify
  end

  def test_submit_plan_to_dalibo_non_redirect_response
    # Test Dalibo submission with non-redirect response (lines ~282-285)
    plan_json = '{"Plan": "test"}'

    mock_response = Minitest::Mock.new
    mock_response.expect(:is_a?, false, [Net::HTTPRedirection])
    mock_response.expect(:code, "500")
    mock_response.expect(:message, "Internal Server Error")

    mock_http = Minitest::Mock.new
    mock_http.expect(:use_ssl=, nil, [true])
    mock_http.expect(:read_timeout=, nil, [10])
    mock_http.expect(:request, mock_response, [Net::HTTP::Post])

    Net::HTTP.stub(:new, mock_http) do
      result = @executor.send(:submit_plan_to_dalibo, plan_json)
      assert_nil result
    end

    mock_response.verify
    mock_http.verify
  end

  def test_submit_plan_to_dalibo_network_error
    # Test Dalibo submission with network error (lines ~286-290)
    plan_json = '{"Plan": "test"}'

    Net::HTTP.stub(:new, -> (*args) { raise StandardError.new("Network error") }) do
      result = @executor.send(:submit_plan_to_dalibo, plan_json)
      assert_nil result
    end
  end

  private

  # Helper class for mocking OpenStruct-like objects
  class OpenStruct
    def initialize(hash)
      @data = hash
    end

    def method_missing(method, *args)
      @data[method]
    end
  end
end