require 'active_support/core_ext'
require 'openc_bot'
require 'json-schema'
require 'openc_bot/helpers/incremental_search'


module OpencBot
  module CompanyFetcherBot
    include OpencBot
    include OpencBot::Helpers::IncrementalSearch

    # This is called by #update_datum (defined in the IncrementalSearch module)
    def fetch_datum(company_number)
      company_page = fetch_registry_page(company_number)
      {:company_page => company_page}
    end

    def fetch_registry_page(company_number)
      _client.get_content(registry_url(company_number))
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

    private
    def _client(options={})
      return @client if @client
      @client = HTTPClient.new(options.delete(:proxy))
      @client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE if options.delete(:skip_ssl_verification)
      @client.agent_name = options.delete(:user_agent)
      @client.ssl_config.ssl_version = options.delete(:ssl_version) if options[:ssl_version]
      if ssl_certificate = options.delete(:ssl_certificate)
        @client.ssl_config.add_trust_ca(ssl_certificate) # Above cert
      end
      @client
    end

  end
end
