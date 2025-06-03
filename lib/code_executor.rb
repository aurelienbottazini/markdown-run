require "tempfile"
require "open3"
require_relative "language_configs"

class CodeExecutor
  def self.execute(code_content, lang, temp_dir, input_file_path = nil, explain = false)
    new.execute(code_content, lang, temp_dir, input_file_path, explain)
  end

  def execute(code_content, lang, temp_dir, input_file_path = nil, explain = false)
    lang_key = lang.downcase
    lang_config = SUPPORTED_LANGUAGES[lang_key]

    return handle_unsupported_language(lang) unless lang_config

    warn "Executing #{lang_key} code block..."

    result = execute_with_config(code_content, lang_config, temp_dir, lang_key, input_file_path, explain)
    process_execution_result(result, lang_config, lang_key, explain)
  end

  private



  def stderr_has_content?(stderr_output)
    stderr_output && !stderr_output.strip.empty?
  end

  def handle_unsupported_language(lang)
    warn "Unsupported language: #{lang}"
    "ERROR: Unsupported language: #{lang}"
  end

  def execute_with_config(code_content, lang_config, temp_dir, lang_key, input_file_path = nil, explain = false)
    cmd_lambda = lang_config[:command]
    temp_file_suffix = lang_config[:temp_file_suffix]

    if temp_file_suffix
      execute_with_temp_file(code_content, cmd_lambda, temp_file_suffix, temp_dir, lang_key, input_file_path, explain)
    else
      execute_direct_command(code_content, cmd_lambda, explain)
    end
  end

  def execute_with_temp_file(code_content, cmd_lambda, temp_file_suffix, temp_dir, lang_key, input_file_path = nil, explain = false)
    result = nil
    Tempfile.create([lang_key, temp_file_suffix], temp_dir) do |temp_file|
      temp_file.write(code_content)
      temp_file.close
      command_to_run, exec_options = cmd_lambda.call(code_content, temp_file.path, input_file_path, explain)

      # Extract output_path if present (for mermaid)
      output_path = exec_options.delete(:output_path) if exec_options.is_a?(Hash)

      captured_stdout, captured_stderr, captured_status_obj = Open3.capture3(command_to_run, **exec_options)
      result = {
        stdout: captured_stdout,
        stderr: captured_stderr,
        status: captured_status_obj,
        output_path: output_path # For mermaid SVG output
      }
    end
    result
  end

  def execute_direct_command(code_content, cmd_lambda, explain = false)
    command_to_run, exec_options = cmd_lambda.call(code_content, nil, nil, explain)
    captured_stdout, captured_stderr, captured_status_obj = Open3.capture3(command_to_run, **exec_options)
    { stdout: captured_stdout, stderr: captured_stderr, status: captured_status_obj }
  end

  def process_execution_result(result, lang_config, lang_key, explain = false)
    exit_status, result_output, stderr_output = format_captured_output(result, lang_config)

    if exit_status != 0
      result_output = add_error_to_output(exit_status, lang_config, lang_key, result_output, stderr_output)
    elsif lang_config && lang_config[:result_handling] == :mermaid_svg
      result_output = handle_mermaid_svg_result(result, lang_key)
    elsif explain && lang_key == "psql"
      result_output = handle_psql_explain_result(result_output)
    end

    result_output
  end

  def format_captured_output(result, lang_config)
    result_output = result[:stdout]
    stderr_output = result[:stderr]
    exit_status = result[:status].exitstatus

    # JS-specific: Append stderr to result if execution failed and stderr has content
    if lang_config && lang_config[:error_handling] == :js_specific && exit_status != 0 && stderr_has_content?(stderr_output)
      result_output += "\nStderr:\n#{stderr_output.strip}"
    end

    [exit_status, result_output, stderr_output]
  end

  def add_error_to_output(exit_status, lang_config, lang_key, result_output, stderr_output)
    warn "Code execution failed for language '#{lang_key}' with status #{exit_status}."
    warn "Stderr:\n#{stderr_output}" if stderr_has_content?(stderr_output)

    is_js_error_already_formatted = lang_config && lang_config[:error_handling] == :js_specific && result_output.include?("Stderr:")
    unless result_output.downcase.include?("error:") || is_js_error_already_formatted
      error_prefix = "Execution failed (status: #{exit_status})."
      error_prefix += " Stderr: #{stderr_output.strip}" if stderr_has_content?(stderr_output)
      result_output = "#{error_prefix}\n#{result_output}"
    end
    result_output
  end

  def stderr_has_content?(stderr_output)
    stderr_output && !stderr_output.strip.empty?
  end

  def handle_mermaid_svg_result(result, lang_key)
    output_path = result[:output_path]

    unless output_path && File.exist?(output_path)
      warn "Warning: Mermaid SVG file not generated at expected path: #{output_path}"
      return "Error: SVG file not generated"
    end

    # Generate relative path for the SVG file
    # If the SVG is in a subdirectory, include the directory in the path
    output_dir = File.dirname(output_path)
    svg_filename = File.basename(output_path)

    # Check if SVG is in a subdirectory (new behavior) or same directory (fallback)
    parent_dir = File.dirname(output_dir)
    if File.basename(output_dir) != File.basename(parent_dir)
      # SVG is in a subdirectory, use relative path with directory
      relative_path = "#{File.basename(output_dir)}/#{svg_filename}"
    else
      # SVG is in same directory (fallback behavior)
      relative_path = svg_filename
    end

    warn "Generated Mermaid SVG: #{relative_path}"

    # Return markdown image tag instead of typical result content
    "![Mermaid Diagram](#{relative_path})"
  end

  def handle_psql_explain_result(result_output)
    require 'json'
    require 'net/http'
    require 'uri'

    # Try to parse the result as JSON (EXPLAIN output)
    begin
      # Clean up the result output and try to parse as JSON
      json_data = JSON.parse(result_output.strip)

      # Submit plan to Dalibo via POST request
      dalibo_url = submit_plan_to_dalibo(JSON.generate(json_data))

      if dalibo_url
        # Return a special format that the markdown processor can parse
        "DALIBO_LINK:#{dalibo_url}\n#{result_output.strip}"
      else
        # If submission failed, just return the original output
        result_output
      end
    rescue JSON::ParserError
      # If it's not valid JSON, just return the original output
      result_output
    end
  end

  private

  def submit_plan_to_dalibo(plan_json)
    begin
      uri = URI('https://explain.dalibo.com/new')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10

      payload = {
        'plan' => plan_json,
        'title' => "Query Plan - #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}",
        'query' => ''
      }

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate(payload)

      response = http.request(request)

      if response.is_a?(Net::HTTPRedirection)
        location = response['location']
        if location
          if location.start_with?('/')
            location = "https://explain.dalibo.com#{location}"
          end
          location
        else
          nil
        end
      else
        warn "Failed to submit plan to Dalibo: #{response.code} #{response.message}"
        nil
      end
    rescue => e
      warn "Error submitting plan to Dalibo: #{e.message}"
      nil
    end
  end
end
