require_relative "language_configs"
require_relative "markdown_processor"
require_relative "markdown_file_writer"

module MarkdownRun
  def self.run_code_blocks(input_file_path)
    unless File.exist?(input_file_path) && File.readable?(input_file_path)
      abort "Error: Input file '#{input_file_path}' not found or not readable."
    end

    temp_dir = File.dirname(File.expand_path(input_file_path))
    file_enum = File.foreach(input_file_path, chomp: false).to_enum

    processor = MarkdownProcessor.new(temp_dir)
    output_lines = processor.process_file(file_enum)

    # Write the modified content back to the input file
    MarkdownFileWriter.write_output_to_file(output_lines, input_file_path)
  end
end
