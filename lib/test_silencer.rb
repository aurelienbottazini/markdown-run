# Module to provide test-aware warning functionality
module TestSilencer
  # Helper method to detect if we're running in a test environment
  def self.running_tests?
    # Check for common test environment indicators
    @running_tests ||= begin
      caller.any? { |line| line.include?('/test/') || line.include?('minitest') || line.include?('rspec') } ||
      defined?(Minitest) ||
      ENV['RAILS_ENV'] == 'test' ||
      ENV['RACK_ENV'] == 'test' ||
      ($PROGRAM_NAME.include?('rake') && ARGV.include?('test')) ||
      $PROGRAM_NAME.include?('rake_test_loader')
    end
  end

  # Generic warn method that silences output during tests
  def self.warn_unless_testing(message)
    warn message unless running_tests?
  end

  # Silently abort during tests by raising SystemExit without printing the message
  def self.abort_unless_testing(message)
    if running_tests?
      # During tests, raise SystemExit without printing the error message
      raise SystemExit.new(1)
    else
      # In production, use normal abort which prints the message and exits
      abort message
    end
  end

  # Suppress Ruby warnings during tests
  def self.setup_warning_suppression
    if running_tests?
      # Temporarily reduce verbosity during tests
      original_verbose = $VERBOSE
      $VERBOSE = nil
      at_exit { $VERBOSE = original_verbose }
    end
  end
end
