require 'openc_bot/bot_config'
require 'rest_client'

module OpencBot
  module Helpers
    class RawDataDepositor

      BASE_URI = "http://Default-External-1855876749.eu-west-1.elb.amazonaws.com:2001/datum/"
      HEADERS = {
        'X-Hacky-Access-Token' => '4cbc7d3b-fc44-42e6-8ffc-4ab109e945b9'
      }

      def self.deposit_raw_datum(raw_datum_hash)
        depositor = new(raw_datum_hash)
        depositor.deposit_raw_datum
        depositor
      end

      def initialize(raw_datum_hash)
        @raw_datum_files = raw_datum_hash[:raw_data_files]
        @retrieved_at = raw_datum_hash[:retrieved_at]
        @company_id = raw_datum_hash[:company_id]
      end

      def deposit_raw_datum
        send_raw_datum
        delete_raw_datum_file_references
      end

      private

      def send_raw_datum
        endpoint = URI.join(BASE_URI, raw_datum_id).to_s
        request = RestClient::Request.new(
          :method => :post,
          :url => endpoint,
          :headers => HEADERS,
          :payload => {
            :multipart => true,
            "data" => @raw_datum_files.values.map { |f| File.open(f) }
          })
        request.execute
      end

      def delete_raw_datum_file_references
        @raw_datum_files.values.each do |file_location|
          FileUtils.rm(file_location)
        end
      end

      def raw_datum_id
        @raw_datum_id ||= "#{OpencBot::BotConfig.instance.bot_id}--#{OpencBot::BotConfig.instance.run_id}--"\
                          "#{OpencBot::BotConfig.instance.git_sha}--#{@retrieved_at}"
      end
    end
  end
end
