require 'active_support/core_ext'
require 'openc_bot'
require 'json-schema'
require 'openc_bot/helpers/incremental_search'


module CompanyFetcherBot
  include OpencBot
  include OpencBot::Helpers::IncrementalSearch

  def validate_datum(record)
    schema = File.expand_path("../../schemas/company-schema.json", __FILE__)
    errors = JSON::Validator.fully_validate(
      schema,
      record.to_json,
      {:errors_as_objects => true})
  end

  private
  def _client(options={})
    @client ||= HTTPClient.new
  end

end
