require_relative 'test_helper'
require_relative '../lib/markdown_file_writer'
require 'tempfile'
require 'fileutils'

class MarkdownFileWriterTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @input_file = File.join(@temp_dir, "test_file.md")
    @output_lines = ["# Test\n", "Some content\n", "More content\n"]

    # Create a test input file
    File.write(@input_file, "Original content")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  def test_write_output_to_file_successful
    result = MarkdownFileWriter.write_output_to_file(@output_lines, @input_file)

    assert_equal true, result
    assert_equal "# Test\nSome content\nMore content\n", File.read(@input_file)
  end

  def test_write_output_to_file_empty_output
    empty_lines = []
    result = MarkdownFileWriter.write_output_to_file(empty_lines, @input_file)

    assert_equal true, result
    assert_equal "", File.read(@input_file)
  end

  def test_write_output_to_file_single_line
    single_line = ["Single line content\n"]
    result = MarkdownFileWriter.write_output_to_file(single_line, @input_file)

    assert_equal true, result
    assert_equal "Single line content\n", File.read(@input_file)
  end

  def test_write_output_to_file_with_different_extension
    txt_file = File.join(@temp_dir, "test_file.txt")
    File.write(txt_file, "Original txt content")

    result = MarkdownFileWriter.write_output_to_file(@output_lines, txt_file)

    assert_equal true, result
    assert_equal "# Test\nSome content\nMore content\n", File.read(txt_file)
  end

  def test_write_output_to_file_with_nested_directory
    nested_dir = File.join(@temp_dir, "nested", "deeper")
    FileUtils.mkdir_p(nested_dir)
    nested_file = File.join(nested_dir, "nested_file.md")
    File.write(nested_file, "Original nested content")

    result = MarkdownFileWriter.write_output_to_file(@output_lines, nested_file)

    assert_equal true, result
    assert_equal "# Test\nSome content\nMore content\n", File.read(nested_file)
  end

  def test_write_output_to_file_handles_eacces_exception
    # Mock FileUtils.mv to raise EACCES
    FileUtils.stub(:mv, ->(_src, _dest) { raise Errno::EACCES.new("Permission denied") }) do
      # Test that the fallback mechanism works (warnings are silenced during tests)
      result = MarkdownFileWriter.write_output_to_file(@output_lines, @input_file)
      assert_equal true, result

      # Verify the content was still written (via the fallback mechanism)
      assert_equal "# Test\nSome content\nMore content\n", File.read(@input_file)
    end
  end

  def test_write_output_to_file_handles_exdev_exception
    # Mock FileUtils.mv to raise EXDEV (cross-device link)
    FileUtils.stub(:mv, ->(_src, _dest) { raise Errno::EXDEV.new("Invalid cross-device link") }) do
      # Test that the fallback mechanism works (warnings are silenced during tests)
      result = MarkdownFileWriter.write_output_to_file(@output_lines, @input_file)
      assert_equal true, result

      # Verify the content was still written (via the fallback mechanism)
      assert_equal "# Test\nSome content\nMore content\n", File.read(@input_file)
    end
  end

  def test_write_output_to_file_fallback_copy_and_delete_mechanism
    mv_called = false
    cp_called = false
    rm_f_called = false

    # Store original methods for fallback calls
    original_cp = FileUtils.method(:cp)
    original_rm_f = FileUtils.method(:rm_f)

    # Mock FileUtils.mv to raise exception, cp and rm_f to track calls
    FileUtils.stub(:mv, ->(_src, _dest) {
      mv_called = true
      raise Errno::EACCES.new("Permission denied")
    }) do
      FileUtils.stub(:cp, ->(src, dest) {
        cp_called = true
        original_cp.call(src, dest)
      }) do
        FileUtils.stub(:rm_f, ->(path) {
          rm_f_called = true
          original_rm_f.call(path)
        }) do
          # Capture the warning to suppress it in test output
          capture_io do
            result = MarkdownFileWriter.write_output_to_file(@output_lines, @input_file)
            assert_equal true, result
          end

          # Verify all the expected method calls happened
          assert mv_called, "FileUtils.mv should have been called"
          assert cp_called, "FileUtils.cp should have been called as fallback"
          assert rm_f_called, "FileUtils.rm_f should have been called to clean up temp file"

          # Verify the content was written correctly
          assert_equal "# Test\nSome content\nMore content\n", File.read(@input_file)
        end
      end
    end
  end

  def test_write_output_to_file_with_binary_content
    binary_lines = ["\x00\x01\x02binary content\x03\x04\x05"]
    result = MarkdownFileWriter.write_output_to_file(binary_lines, @input_file)

    assert_equal true, result
    assert_equal "\x00\x01\x02binary content\x03\x04\x05", File.read(@input_file)
  end

  def test_write_output_to_file_with_unicode_content
    unicode_lines = ["# Unicode Test 🚀\n", "Content with émojis and spéciál characters\n", "中文内容\n"]
    result = MarkdownFileWriter.write_output_to_file(unicode_lines, @input_file)

    assert_equal true, result
    expected_content = "# Unicode Test 🚀\nContent with émojis and spéciál characters\n中文内容\n"
    assert_equal expected_content, File.read(@input_file)
  end

  def test_write_output_to_file_preserves_exact_content
    # Test that no extra newlines or modifications are added
    precise_lines = ["Line 1", "Line 2\n", "Line 3\n\n", "Line 4"]
    result = MarkdownFileWriter.write_output_to_file(precise_lines, @input_file)

    assert_equal true, result
    assert_equal "Line 1Line 2\nLine 3\n\nLine 4", File.read(@input_file)
  end

  def test_write_output_to_file_large_content
    # Test with larger content to ensure it handles bigger files
    large_lines = Array.new(1000) { |i| "Line #{i}: #{SecureRandom.hex(50)}\n" }
    result = MarkdownFileWriter.write_output_to_file(large_lines, @input_file)

    assert_equal true, result
    written_content = File.read(@input_file)
    assert_equal large_lines.join(""), written_content
    assert_includes written_content, "Line 0:"
    assert_includes written_content, "Line 999:"
  end

  def test_class_method_interface
    # Verify this is a class method, not instance method
    assert_respond_to MarkdownFileWriter, :write_output_to_file
    refute_respond_to MarkdownFileWriter.new, :write_output_to_file
  end

  def test_temp_file_creation_in_correct_directory
    # Ensure temp files are created in the same directory as the target file
    subdirectory = File.join(@temp_dir, "subdir")
    FileUtils.mkdir_p(subdirectory)
    target_file = File.join(subdirectory, "target.md")
    File.write(target_file, "original")

    # Monitor temp file creation
    temp_dir_used = nil
    original_create = Tempfile.method(:create)

    stub_create = ->(prefix_suffix, tmpdir = nil, &block) {
      temp_dir_used = tmpdir
      original_create.call(prefix_suffix, tmpdir, &block)
    }

    Tempfile.stub(:create, stub_create) do
      MarkdownFileWriter.write_output_to_file(@output_lines, target_file)
      assert_equal subdirectory, temp_dir_used
    end
  end
end