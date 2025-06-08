require_relative "flamegraph_helper"
require_relative "test_silencer"

module ResultHelper
  include FlamegraphHelper

  private

  def ruby_style_result?(lang)
    lang_config = SUPPORTED_LANGUAGES[lang]
    lang_config && lang_config[:result_block_type] == "ruby"
  end

  def mermaid_style_result?(lang)
    lang_config = SUPPORTED_LANGUAGES[lang]
    lang_config && lang_config[:result_handling] == :mermaid_svg
  end

  def result_block_header(lang)
    ruby_style_result?(lang) ? "```ruby RESULT\n" : "```RESULT\n"
  end

  def result_block_regex(lang)
    if mermaid_style_result?(lang)
      # For mermaid, look for existing image tags with .svg extension
      /^!\[.*\]\(.*\.svg\)$/i
    elsif ruby_style_result?(lang)
      /^```ruby\s+RESULT$/i
    else
      /^```RESULT$/i
    end
  end

  def add_result_block(result_output, blank_line_before_new_result)
    if mermaid_style_result?(@current_block_lang)
      # For mermaid, add the image tag directly without a result block
      @output_lines << "\n" if blank_line_before_new_result.nil?
      @output_lines << result_output
      @output_lines << "\n" unless result_output.empty? || result_output.end_with?("\n")
      @output_lines << "\n"
    else
      @output_lines << "\n" if blank_line_before_new_result.nil?
      @output_lines << result_block_header(@current_block_lang)
      @output_lines << result_output
      @output_lines << "\n" unless result_output.empty? || result_output.end_with?("\n")
      @output_lines << "```\n\n"
    end
  end


  def handle_inside_result_block(current_line, file_enum)
    @output_lines << current_line
    if is_block_end?(current_line)
      @state = :outside_code_block
    end
  end

  def handle_existing_ruby_result_block(current_line, file_enum)
    TestSilencer.warn_unless_testing("Found existing '```ruby RESULT' block, passing through.")
    @output_lines << current_line
    @state = :inside_result_block
  end


  def execute_and_add_result(blank_line_before_new_result)
      TestSilencer.warn_unless_testing("Skipping empty code block for language '#{@current_block_lang}'.") && return unless has_content?(@current_code_content)

    @output_lines << blank_line_before_new_result if blank_line_before_new_result

    result_output = CodeExecutor.execute(@current_code_content, @current_block_lang, @temp_dir, @input_file_path, @current_block_explain, @current_block_flamegraph)

    # Check if result contains a Dalibo link for psql explain queries
    dalibo_link, result_after_dalibo = extract_dalibo_link(result_output)

    # Check if result contains a flamegraph link for psql flamegraph queries
    flamegraph_link, clean_result = extract_flamegraph_link(result_after_dalibo)

    # Add the result block only if result=true (default)
    if @current_block_result
      add_result_block(clean_result || result_after_dalibo, blank_line_before_new_result)
    end

    # Always add Dalibo link if it exists, even when result=false
    if dalibo_link
      # Add appropriate spacing based on whether result block was shown
      if @current_block_result
        @output_lines << "#{dalibo_link}\n\n"
      else
        @output_lines << "\n#{dalibo_link}\n\n"
      end
    end

    # Always add flamegraph link if it exists, even when result=false
    if flamegraph_link
      # Add appropriate spacing based on whether result block was shown
      if @current_block_result || dalibo_link
        @output_lines << "#{flamegraph_link}\n\n"
      else
        @output_lines << "\n#{flamegraph_link}\n\n"
      end
    end
  end

  def skip_and_pass_through_result(lines_to_pass_through, file_enum, decision = nil)
    # Handle run=false case where there are no lines to pass through
    if lines_to_pass_through.empty?
      TestSilencer.warn_unless_testing("Skipping execution due to run=false option.")
      return
    end

    # Check if this is Dalibo content
    if decision && decision[:dalibo_content]
      TestSilencer.warn_unless_testing("Found existing Dalibo link for current #{@current_block_lang} block, skipping execution.")
      @output_lines.concat(lines_to_pass_through)
      # No additional consumption needed for Dalibo links
      return
    end

    # Check if this is flamegraph content
    if decision && decision[:flamegraph_content]
      TestSilencer.warn_unless_testing("Found existing flamegraph for current #{@current_block_lang} block, skipping execution.")
      @output_lines.concat(lines_to_pass_through)
      # No additional consumption needed for flamegraph links
      return
    end

    if mermaid_style_result?(@current_block_lang)
      TestSilencer.warn_unless_testing("Found existing mermaid SVG image for current #{@current_block_lang} block, skipping execution.")
      @output_lines.concat(lines_to_pass_through)
      # For mermaid, no additional consumption needed since it's just an image line
    else
      lang_specific_result_type = ruby_style_result?(@current_block_lang) ? "```ruby RESULT" : "```RESULT"
      TestSilencer.warn_unless_testing("Found existing '#{lang_specific_result_type}' block for current #{@current_block_lang} block, skipping execution.")
      @output_lines.concat(lines_to_pass_through)
      consume_result_block_content(file_enum)
    end
  end

  def consume_result_block_content(file_enum)
    consume_block_lines(file_enum) do |line|
      @output_lines << line
    end
  end

  def consume_existing_result_block(file_enum, consumed_lines)
    return if mermaid_style_result?(@current_block_lang)

    consume_block_lines(file_enum) do |line|
      consumed_lines << line
    end

    consume_dalibo_link_if_present(file_enum, consumed_lines)
    consume_flamegraph_link_if_present(file_enum, consumed_lines)
  end


  def consume_block_lines(file_enum)
    begin
      loop do
        result_block_line = file_enum.next
        yield result_block_line
        break if is_block_end?(result_block_line)
      end
    rescue StopIteration
      TestSilencer.warn_unless_testing "Warning: End of file reached while consuming result block."
    end
  end
end
