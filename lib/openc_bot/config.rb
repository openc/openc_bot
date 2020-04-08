require "json"
require "net/http"
require "ostruct"

module OpencBot
  # This is called from company_fetcher_bot
  module Config
    BOTS_JSON_URL = ENV.fetch("ANALYSIS_BOTS_JSON_URL").freeze

    def db_config
      @db_config ||= OpenStruct.new(JSON.parse(Net::HTTP.get(URI(BOTS_JSON_URL))).select { |bot| bot["bot_id"] == "#{OpencBot::CompanyFetcherBot.jurisdiction_code}_companies" }.first)
    end
  end
end
