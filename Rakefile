require "bundler/gem_tasks"
require "openc_bot/tasks"

$LOAD_PATH.unshift File.dirname(__FILE__) + "/../../lib"
# require 'resque/tasks'

Dir.glob("lib/tasks/*.rake").each { |r| import r }

begin
  require "rspec/core/rake_task"
  task default: :spec
  RSpec::Core::RakeTask.new
rescue LoadError
  # do nothing
end
