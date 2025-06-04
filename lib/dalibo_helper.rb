module DaliboHelper
  private

  DALIBO_LINK_PREFIX = "DALIBO_LINK:"

  def extract_dalibo_link(result_output)
    # Check if the result contains a Dalibo link marker
    if result_output.start_with?(DALIBO_LINK_PREFIX)
      lines = result_output.split("\n", 2)
      dalibo_url = lines[0].sub(DALIBO_LINK_PREFIX, "")
      clean_result = lines[1] || ""
      dalibo_link = "[Dalibo](#{dalibo_url})"
      [dalibo_link, clean_result]
    else
      [nil, result_output]
    end
  end

  def consume_dalibo_link_if_present(file_enum, consumed_lines)
    # Look ahead to see if there are Dalibo links after the result block
    begin
      # Keep consuming blank lines and Dalibo links until we hit something else
      loop do
        next_line = peek_next_line(file_enum)

        if is_blank_line?(next_line)
          consumed_lines << file_enum.next
        elsif next_line&.start_with?("[Dalibo]")
          consumed_lines << file_enum.next
        else
          # Hit something that's not a blank line or Dalibo link, stop consuming
          break
        end
      end
    rescue StopIteration
      # End of file reached, nothing more to consume
    end
  end
end