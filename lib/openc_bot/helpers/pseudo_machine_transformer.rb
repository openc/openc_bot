# frozen_string_literal: true

require "openc_bot/helpers/persistence_handler"
require "openc_bot/pseudo_machine_company_fetcher_bot"
require "openc_bot/helpers/pseudo_machine_register_methods"

module OpencBot
  module Helpers
    # Transformer activities
    module PseudoMachineTransformer
      include OpencBot
      include OpencBot::PseudoMachineCompanyFetcherBot
      include OpencBot::Helpers::PersistenceHandler
      include OpencBot::Helpers::PsuedoMachineRegisterMethods

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
          unless entity_datum.blank?
            validation_errors = validate_datum(entity_datum)
            raise "\n#{JSON.pretty_generate([entity_datum, validation_errors])}" unless validation_errors.blank?

            persist(entity_datum)
            save_entity(entity_datum) unless ENV["NO_SAVE_DATA_IN_SQLITE"]
            counter += 1
          end
        end
        { transformed: counter, transformer_start: start_time, transformer_end: Time.now.utc }
      end

      def schema_name
        super || "company-schema"
      end
    end
  end
end
