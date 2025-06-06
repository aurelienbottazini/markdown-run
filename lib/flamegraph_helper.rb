module FlamegraphHelper
  private

  FLAMEGRAPH_LINK_PREFIX = "FLAMEGRAPH_LINK:"

  def extract_flamegraph_link(result_output)
    # Check if the result contains a flamegraph link marker
    if result_output.start_with?(FLAMEGRAPH_LINK_PREFIX)
      lines = result_output.split("\n", 2)
      flamegraph_path = lines[0].sub(FLAMEGRAPH_LINK_PREFIX, "")
      clean_result = lines[1] || ""
      flamegraph_link = "![PostgreSQL Query Flamegraph](#{flamegraph_path})"
      [flamegraph_link, clean_result]
    else
      [nil, result_output]
    end
  end

  def consume_flamegraph_link_if_present(file_enum, consumed_lines)
    # Look ahead to see if there are flamegraph links after the result block
    begin
      # Keep consuming blank lines and flamegraph links until we hit something else
      loop do
        next_line = peek_next_line(file_enum)

        if is_blank_line?(next_line)
          consumed_lines << file_enum.next
        elsif next_line&.start_with?("![PostgreSQL Query Flamegraph]")
          consumed_lines << file_enum.next
        else
          # Hit something that's not a blank line or flamegraph link, stop consuming
          break
        end
      end
    rescue StopIteration
      # End of file reached, nothing more to consume
    end
  end
end