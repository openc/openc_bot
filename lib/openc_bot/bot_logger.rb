require 'forwardable'
require 'logger'
require 'singleton'

class BotLogger
  extend Forwardable
  include Singleton

  def initialize
    @logger = Logger.new($stdout)
    log_level = ENV.fetch('RUBY_LOG_LEVEL', 'INFO')
    @logger.level = Logger.const_get(log_level)
  end

  def logger
    @logger
  end

  def_delegators :@logger, :info, :warn, :debug, :error, :fatal
end
