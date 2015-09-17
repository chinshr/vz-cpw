require "bundler/gem_tasks"
require "rake/testtask"
require "mkmf"

Rake::TestTask.new do |t|
  t.test_files = FileList['test/**/*_test.rb']
end

task default: :test

desc "Generating yard docs"
task :yard do
  'yard doc'
end

task :check do
  puts "Checking dependencies..."
  find_executable 'ruby'
  find_executable 'rvm'
  find_executable 'git'
  find_executable 'ffmpeg'
  find_executable 'sox'
  find_executable 'wav2json'
  find_executable 'pocketsphinx_continuous'
end