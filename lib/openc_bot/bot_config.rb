require 'singleton'

module OpencBot
  class BotConfig
    include Singleton
    attr_accessor :run_id
    attr_reader :git_sha, :bot_id

    def initialize
      @run_id = "0"
      @git_sha = `git rev-parse --short HEAD`.chomp
      @bot_id = Dir.pwd.split("/").last
    end
  end
end