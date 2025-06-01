require "tempfile"
require "open3"
require_relative "language_configs"

class CodeExecutor
  def self.execute(code_content, lang, temp_dir)
    new.execute(code_content, lang, temp_dir)
  end

  def execute(code_content, lang, temp_dir)
    lang_key = lang.downcase
    lang_config = SUPPORTED_LANGUAGES[lang_key]

    return handle_unsupported_language(lang) unless lang_config

    warn "Executing #{lang_key} code block..."

    result = execute_with_config(code_content, lang_config, temp_dir, lang_key)
    process_execution_result(result, lang_config, lang_key)
  end

  private

  def handle_unsupported_language(lang)
    warn "Unsupported language: #{lang}"
    "ERROR: Unsupported language: #{lang}"
  end

  def execute_with_config(code_content, lang_config, temp_dir, lang_key)
    cmd_lambda = lang_config[:command]
    temp_file_suffix = lang_config[:temp_file_suffix]

    if temp_file_suffix
      execute_with_temp_file(code_content, cmd_lambda, temp_file_suffix, temp_dir, lang_key)
    else
      execute_direct_command(code_content, cmd_lambda)
    end
  end

  def execute_with_temp_file(code_content, cmd_lambda, temp_file_suffix, temp_dir, lang_key)
    result = nil
    Tempfile.create([lang_key, temp_file_suffix], temp_dir) do |temp_file|
      temp_file.write(code_content)
      temp_file.close
      command_to_run, exec_options = cmd_lambda.call(code_content, temp_file.path)
      captured_stdout, captured_stderr, captured_status_obj = Open3.capture3(command_to_run, **exec_options)
      result = { stdout: captured_stdout, stderr: captured_stderr, status: captured_status_obj }
    end
    result
  end

  def execute_direct_command(code_content, cmd_lambda)
    command_to_run, exec_options = cmd_lambda.call(code_content, nil)
    captured_stdout, captured_stderr, captured_status_obj = Open3.capture3(command_to_run, **exec_options)
    { stdout: captured_stdout, stderr: captured_stderr, status: captured_status_obj }
  end

  def process_execution_result(result, lang_config, lang_key)
    exit_status, result_output, stderr_output = format_captured_output(result, lang_config)

    if exit_status != 0
      result_output = add_error_to_output(exit_status, lang_config, lang_key, result_output, stderr_output)
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
end
