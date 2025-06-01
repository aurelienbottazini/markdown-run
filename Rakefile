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

task default: :test
