# frozen_string_literal: true

require "openc_bot/helpers/persistence_handler"

module OpencBot
  module Helpers
    module PseudoMachineParser
      include OpencBot::Helpers::PersistenceHandler

      def input_stream
        "fetcher"
      end

      def parse(fetched_datum)
        # implement in bot
        # may return either a single parsed datum or an array of data from
        # single fetched_datum, e.g. if fetched_datum is a CSV file
      end

      def run
        start_time = Time.now.utc
        counter = 0
        get_input_data do |fetched_datum|
          parsed_data = parse(fetched_datum)
          parsed_data = [parsed_data] unless parsed_data.is_a?(Array)
          parsed_data.each do |parsed_datum|
            persist(parsed_datum)
            counter += 1
          end
        end
        {parsed: counter, parser_start: start_time, parser_end: Time.now.utc}
      end
    end
  end
end
