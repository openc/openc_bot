# frozen_string_literal: true

module OpencBot
  module Helpers
    # Transformer activities
    module PseudoMachineTransformer
      include OpencBot
      include OpencBot::Helpers::PersistenceHandler
      include OpencBot::Helpers::RegisterMethods

      def development?
        ENV["FETCHER_BOT_ENV"] == "development"
      end

      def input_stream
        "parser"
      end

      def encapsulate_as_per_schema(parsed_datum)
        # define in bot
        # note: should explicitly include the jurisdiction code as this can't
        # be inferred from the transformer name
      end

      def run
        counter = 0
        start_time = Time.now.utc
        input_data do |json_data|
          entity_datum = encapsulate_as_per_schema(json_data)
          unless entity_datum.nil?
            persist(entity_datum)
            save_entity!(entity_datum) if development? || ENV["SAVE_DATA_IN_SQLITE"]
          end

          counter += 1
        end
        { transformed: counter, transformer_start: start_time, transformer_end: Time.now.utc }
      end

      def schema_name
        super || "company-schema"
      end
    end
  end
end
