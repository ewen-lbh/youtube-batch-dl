require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rake/extensiontask"

task :build => :compile

Rake::ExtensionTask.new("youtube_batch_dl") do |ext|
  ext.lib_dir = "lib/youtube_batch_dl"
end

task :default => [:clobber, :compile, :spec]
