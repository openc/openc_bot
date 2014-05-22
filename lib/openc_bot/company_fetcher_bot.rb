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

    def inferred_jurisdiction_code
      poss_j_code = self.name.sub(/CompaniesFetcher/,'').underscore
      poss_j_code[/^[a-z]{2}$|^[a-z]{2}_[a-z]{2}$/]
    end

    def primary_key_name
      :company_number
    end

    # This overrides default #save_entity (defined in RegisterMethods) and adds
    # the inferred jurisdiction_code, unless it is overridden in entity_info
    def save_entity(entity_info)
      return if entity_info.blank?
      default_options = {:jurisdiction_code => inferred_jurisdiction_code}
      super(default_options.merge(entity_info))
    end

    def save_entity!(entity_info)
      return if entity_info.blank?
      default_options = {:jurisdiction_code => inferred_jurisdiction_code}
      super(default_options.merge(entity_info))
    end

    def schema_name
      super || 'company-schema'
    end

  end
end
