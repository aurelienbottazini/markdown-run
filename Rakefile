require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
end

desc "Run flog complexity analysis on the entire project"
task :flog do
  puts "Running flog complexity analysis..."
  system("flog lib/ exe/ test/")
end

desc "Run flog with detailed method breakdown"
task :flog_detailed do
  puts "Running detailed flog analysis..."
  system("flog -d lib/ exe/ test/")
end

desc "Run tests with detailed timing information"
task :test_profile do
  require 'benchmark'
  
  puts "Running tests with detailed profiling..."
  
  # Run tests with verbose output and capture timing
  output = `bundle exec rake test TESTOPTS="-v" 2>&1`
  
  # Extract test timings
  timings = []
  output.scan(/^(.+) = ([0-9]+\.[0-9]+) s = \.$/) do |test_name, time|
    timings << [test_name, time.to_f]
  end
  
  # Sort by time (descending)
  timings.sort_by! { |_, time| -time }
  
  puts "\n" + "="*80
  puts "TOP 15 SLOWEST TESTS"
  puts "="*80
  
  timings.first(15).each_with_index do |(test_name, time), index|
    test_display = test_name.length > 60 ? test_name[0...60] + "..." : test_name
    printf "%2d. %-63s %6.2f s\n", index + 1, test_display, time
  end
  
  puts "\n" + "="*80
  puts "SUMMARY"
  puts "="*80
  total_time = timings.sum { |_, time| time }
  slow_tests = timings.select { |_, time| time > 0.1 }
  
  puts "Total test time: #{total_time.round(2)} seconds"
  puts "Tests slower than 0.1s: #{slow_tests.count}"
  puts "Time spent in slow tests: #{slow_tests.sum { |_, time| time }.round(2)} seconds (#{((slow_tests.sum { |_, time| time } / total_time) * 100).round(1)}%)"
end

desc "Release"
task :release do
  `gem bump`
  `bundle`
  `git commit --amend`
  `git push`
  `git push --tags`
  `gem release`
end

# Coverage task
desc "Run tests with SimpleCov coverage report"
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task[:test].invoke

  puts "\n🎯 Coverage Report Generated!"
  puts "📊 Open coverage/index.html to view detailed coverage report"

  # Try to open coverage report automatically (works on macOS)
  if RUBY_PLATFORM.include?('darwin')
    system('open coverage/index.html')
  end
end

task default: :test
