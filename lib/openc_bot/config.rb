require "json"
require "net/http"
require "ostruct"

module OpencBot
  # This is called from company_fetcher_bot
  module Config
    BOTS_JSON_URL = ENV["ANALYSIS_BOTS_JSON_URL"]

    def set_variables
      return if @db_config

      config?.marshal_dump.each { |k, v| instance_variable_set("@#{k}", v) } unless config?.nil?
    end

    def db_config
      return if BOTS_JSON_URL.nil?

      @db_config ||= JSON.parse(Net::HTTP.get(URI(BOTS_JSON_URL))).select { |bot| bot["bot_id"] == "#{jurisdiction_code}_companies" }.first
    end

    def config?
      OpenStruct.new(db_config["bot_config"])
    rescue NoMethodError
      nil
    end
  end
end
