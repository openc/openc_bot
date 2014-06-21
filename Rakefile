require "bundler/gem_tasks"
require 'openc_bot/tasks'


$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
# require 'resque/tasks'

Dir.glob('lib/tasks/*.rake').each { |r| import r }
rspec_present = require 'rspec/core/rake_task' rescue nil
if rspec_present
  require 'rspec/core/rake_task'
  task :default => :spec
end

RSpec::Core::RakeTask.new