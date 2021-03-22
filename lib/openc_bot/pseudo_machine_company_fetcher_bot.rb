# frozen_string_literal: true

require "openc_bot/company_fetcher_bot"
require "openc_bot/helpers/persistence_handler"

module OpencBot
  # Psuedo machine activity handler
  module PseudoMachineCompanyFetcherBot
    include OpencBot::CompanyFetcherBot
    include OpencBot::Helpers::PersistenceHandler

    def bot_name
      @bot_name ||= Dir.pwd.split("/").last
    end

    def callable_from_file_name(underscore_file_name)
      bot_klass = klass_from_file_name(underscore_file_name)
      if bot_klass.respond_to?(:new)
        bot_klass.new
      else
        bot_klass
      end
    end

    # Outline bot run logic.
    def update_data(options = {})
      res = {}
      bot_namespace = callable_from_file_name(bot_name)
      res.merge!(bot_namespace::Fetcher.run)
      res.merge!(bot_namespace::Parser.run)
      transformed_result_data = bot_namespace::Transformer.run
      res.merge!(transformed_result_data)
      # rename directory so it will be seen by importer
      mark_acquisition_directory_as_finished_processing
      res[:data_directory] = acquisition_directory_final
      res
    rescue StandardError => e
      send_error_report(e, options)
      raise e
    end
  end
end
