require 'openc_bot/bot_config'
require 'postbox_client'

module OpencBot
  module Helpers
    class RawDataDepositor
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
        postbox_client.upload_datum_files(
          @raw_datum_files.values.map { |f| File.new(f) },
          OpencBot::BotConfig.instance.bot_id,
          Time.at(OpencBot::BotConfig.instance.run_id).utc.iso8601.sub(/\+00:00$/, "Z"),
          OpencBot::BotConfig.instance.git_sha,
          @retrieved_at
        )
      end

      def postbox_client
        @postbox_client ||= connect_to_postbox
      end

      def connect_to_postbox
        # server_url = "http://Default-External-1855876749.eu-west-1.elb.amazonaws.com:2001"
        # server_url = "http://a54dbfc3eaefd412b9f6982d7fd2adca-1931796360.eu-west-2.elb.amazonaws.com"
        server_url = "http://localhost:8000"

        api_instance = PostboxClient::DefaultApi.new(server_url)
      end

      def delete_raw_datum_file_references
        @raw_datum_files.values.each do |file_location|
          FileUtils.rm(file_location)
        end
      end
    end
  end
end
