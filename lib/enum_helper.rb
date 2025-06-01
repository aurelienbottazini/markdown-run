module EnumHelper
  private

  def safe_enum_operation(file_enum, operation)
    file_enum.send(operation)
  rescue StopIteration
    nil
  end

  def get_next_line(file_enum)
    safe_enum_operation(file_enum, :next)
  end

  def peek_next_line(file_enum)
    safe_enum_operation(file_enum, :peek)
  end
end
