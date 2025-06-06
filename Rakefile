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
