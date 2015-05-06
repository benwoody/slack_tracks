require 'rake/testtask'

task :test => ["test:all"]

task :default => "test:all"

namespace :test do
  desc "Run all tests"
  Rake::TestTask.new(:all) do |t|
    t.libs << "test"
    t.test_files = FileList['test/test_*.rb']
    t.verbose = true
  end
end
