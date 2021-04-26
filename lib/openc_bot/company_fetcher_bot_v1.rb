# frozen_string_literal: true

require "openc_bot/company_fetcher_bot"
require "openc_bot/helpers/dataset_based"

module OpencBot
  # Extending the behaviour for the CompanyFetcherBot
  module CompanyFetcherBotV1
    include OpencBot::Helpers::DatasetBased
    include OpencBot::CompanyFetcherBot

    ACQUISITION_ID = ENV["ACQUISITION_ID"] || Time.now.to_i
    ACQUISITION_DIRECTORY = "#{ENV['ACQUISITION_DIRECTORY'] || 'data'}/#{ACQUISITION_ID}"
    @added = 0
    @updated = 0

    # Outline bot run logic. Any information that is returned from #fetch_data
    # or #update_stale (which you should override in preference to overriding
    # this method) will be returned here and included in the final run report.
    def update_data(options = {})
      result = fetch_data.merge(update_stale)
      result.update(added: @added) unless result.key?(:added)
      result.update(updated: @updated) unless result.key?(:added)
      raise "\n#{JSON.pretty_generate(result)}" if result.key?(:fetch_data_error) || result.key?(:update_stale_error)

      result
    rescue StandardError => e
      send_error_report(e, options)
      raise e
    end
  end
end
