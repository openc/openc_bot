# frozen_string_literal: true

require "openc_bot/helpers/register_methods"

module OpencBot
  module Helpers
    # Configuration/Methods overrides for Pseduo Machine related activities
    module PsuedoMachineRegisterMethods
      include OpencBot::Helpers::RegisterMethods

      def save_entity(entity_datum)
        prepare_and_save_data(entity_datum)
      end

      def primary_key_name
        const_defined?("PRIMARY_KEY_NAME") ? const_get("PRIMARY_KEY_NAME") : :company_number
      end

      def exception_to_object(exp)
        { klass: exp.class.to_s, message: exp.message, backtrace: exp.backtrace }
      end
    end
  end
end
