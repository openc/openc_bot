require 'openc_bot'
require 'openc_bot/helpers/incremental_search'
require 'openc_bot/helpers/alpha_search'


module OpencBot
  module CompanyFetcherBot
    include OpencBot
    include OpencBot::Helpers::IncrementalSearch
    include OpencBot::Helpers::AlphaSearch

    # This is called by #update_datum
    def fetch_datum(company_number)
      company_page = fetch_registry_page(company_number)
      {:company_page => company_page}
    end

    def primary_key_name
      :company_number
    end

    def schema_name
      super || 'company-schema'
    end

  end
end
