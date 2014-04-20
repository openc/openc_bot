require "bundler/gem_tasks"
# load 'lib/tasks/openc_bot.rake'
# require 'lib/tasks'
require 'openc_bot/tasks'


$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
# require 'resque/tasks'

Dir.glob('lib/tasks/*.rake').each { |r| import r }

require 'rspec/core/rake_task'
task :default => :spec
RSpec::Core::RakeTask.new