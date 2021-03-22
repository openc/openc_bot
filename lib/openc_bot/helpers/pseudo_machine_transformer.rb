require "openc_bot/helpers/persistence_handler"

module OpencBot
  module Helpers
    module PseudoMachineTransformer
      include OpencBot::Helpers::PersistenceHandler
      include OpencBot::Helpers::RegisterMethods

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
        get_input_data do |json_data|
          entity_datum = encapsulate_as_per_schema(json_data)
          validation_errors = validate_datum(entity_datum)
          persist(entity_datum)
          save_entity!(entity_datum) if development? || ENV["SAVE_DATA_IN_SQLITE"]
          return unless validation_errors.blank?
          counter += 1
        end
        { transformed: counter,
          transformer_start: start_time,
          transformer_end: Time.now.utc
        }
      end

      def schema_name
        super || "company-schema"
      end
    end
  end
end
