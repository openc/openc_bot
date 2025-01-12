require 'logger'
require 'singleton'

class BotLogger
  include Singleton

  def initialize
    @logger = Logger.new($stdout)
    log_level = ENV.fetch('RUBY_LOG_LEVEL', 'INFO')
    @logger.level = Logger.const_get(log_level)
  end

  def logger
    @logger
  end

  def method_missing(method, *args, &block)
    @logger.send(method, *args, &block)
  end
end
