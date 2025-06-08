# Module to provide test-aware warning functionality
module TestSilencer
  # Helper method to detect if we're running in a test environment
  def self.running_tests?
    # Check for common test environment indicators
    caller.any? { |line| line.include?('/test/') || line.include?('minitest') || line.include?('rspec') } ||
    defined?(Minitest) ||
    ENV['RAILS_ENV'] == 'test' ||
    ENV['RACK_ENV'] == 'test' ||
    $PROGRAM_NAME.include?('rake') && ARGV.include?('test')
  end

  # Generic warn method that silences output during tests
  def self.warn_unless_testing(message)
    warn message unless running_tests?
  end
end
