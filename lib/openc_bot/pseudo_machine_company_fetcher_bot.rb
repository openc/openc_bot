# frozen_string_literal: true

require "openc_bot"
require "openc_bot/company_fetcher_bot"

module OpencBot
  module PseudoMachineCompanyFetcherBot
    include OpencBot::CompanyFetcherBot
    include OpencBot::PersistenceHandler

    # Outline bot run logic.
    def update_data(options = {})
      res = {}
      res.merge!(Fetcher.run)
      res.merge!(Parser.run)
      transformed_result_data = Transformer.run
      res.merge!(transformed_result_data)
      # rename directory so it will be seen by importer
      mark_acquisition_directory_as_finished_processing
      res[:data_directory] = acquisition_directory_final
      res
    rescue Exception => e
      send_error_report(e, options)
      raise e
    end

  end
end
