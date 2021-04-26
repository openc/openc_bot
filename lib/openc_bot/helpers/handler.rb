# frozen_string_literal: true

module OpencBot
  module Helpers
    # Activity tracker
    module Handler
      def persist(context, res)
        FileUtils.mkdir(OpencBot::CompanyFetcherBotV1::ACQUISITION_DIRECTORY) unless File.exist?(OpencBot::CompanyFetcherBotV1::ACQUISITION_DIRECTORY)
        IO.write("#{OpencBot::CompanyFetcherBotV1::ACQUISITION_DIRECTORY}/#{context}.json", "#{res.to_json}\n", mode: "a")
      end

      def run(payload = nil)
        context = self.class.name.split("::").last.downcase
        result = super
        if result.instance_of?(Array)
          result.each do |res|
            persist(context, res)
          end
        else
          persist(context, result)
        end
        result
      end
    end
  end
end
