require 'active_support/core_ext'
require 'openc_bot'
require 'json-schema'
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

    def validate_datum(record)
      schema = File.expand_path("../../../schemas/company-schema.json", __FILE__)
      errors = JSON::Validator.fully_validate(
        schema,
        record.to_json,
        {:errors_as_objects => true})
    end

  end
end
