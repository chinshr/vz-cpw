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

desc "Loads CPW environment"
task :environment do
  require 'cpw'
end

namespace :sqs do
  namespace :queues do
    desc "Create SQS queues"
    task :create => :environment do
      sqs = AWS::SQS.new
      CPW::Worker::Base.subclasses.each do |worker_class|
        queue_name = worker_class.queue_name
        puts "Creating '#{queue_name}' queue."
        queue = sqs.queues.create(queue_name)
      end
    end
  end
end