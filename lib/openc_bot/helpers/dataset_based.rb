# frozen_string_literal: true

require "openc_bot/helpers/register_methods_v1"

module OpencBot
  module Helpers
    # Helper which helps in orchestrating the ELT flow of the dataset either available via opendata or procured
    module DatasetBased
      extend OpencBot::Helpers::RegisterMethodsV1
      def fetch_data_via_dataset
        # Parser, Fetcher & Transformer are the classes that are to be defined by the bot
        Parser.new.run(Fetcher.new.run).each do |entry|
          datum = Transformer.new.run(entry)
          save_entity!(datum)
        end
        {}
      end
    end
  end
end
