# frozen_string_literal: true

require "openc_bot/pseudo_machine_company_fetcher_bot"

module OpencBot
  module Helpers
    # Parsing activities
    module PseudoMachineParser
      include OpencBot::PseudoMachineCompanyFetcherBot

      def input_stream
        "fetcher"
      end

      def parse(fetched_datum)
        # implement in bot
        # may return either:
        #   a single parsed datum
        #   an array of data from single fetched_datum, e.g. if fetched_datum is a CSV file
        #   call "yield(parsed_datum)" inside the parse method passing each parsed record, to persist one-by-one
      end

      def run
        start_time = Time.now.utc
        counter = 0
        input_data do |fetched_datum|
          yielded = false
          # the parse method can use yield
          parsed_data = parse(fetched_datum) do |parsed_datum|
            yielded = true
            next if parsed_datum.blank?

            persist(parsed_datum)
            counter += 1
          end

          unless yielded
            parsed_data = [parsed_data] unless parsed_data.is_a?(Array)
            parsed_data.each do |parsed_datum|
              next if parsed_datum.blank?

              persist(parsed_datum)
              counter += 1
            end
          end
        end
        { parsed: counter, parser_start: start_time, parser_end: Time.now.utc }
      end
    end
  end
end
