require "tempfile"
require "fileutils"

class MarkdownFileWriter
  def self.write_output_to_file(output_lines, input_file_path)
    temp_dir = File.dirname(File.expand_path(input_file_path))

    # Write the modified content back to the input file using atomic operations
    Tempfile.create([ "md_exec_out_", File.extname(input_file_path) ], temp_dir) do |temp_output_file|
      temp_output_file.write(output_lines.join(""))
      temp_output_file.close

      begin
        FileUtils.mv(temp_output_file.path, input_file_path)
      rescue Errno::EACCES, Errno::EXDEV
        warn "Atomic move failed. Falling back to copy and delete."
        FileUtils.cp(temp_output_file.path, input_file_path)
        FileUtils.rm_f(temp_output_file.path)
      end
    end

    warn "Markdown processing complete. Output written to #{input_file_path}"
    true # Indicate success
  end
end
