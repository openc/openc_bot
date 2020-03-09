require "openc_bot"
require "openc_bot/helpers/incremental_search"
require "openc_bot/helpers/alpha_search"
require "openc_bot/helpers/reporting"

module OpencBot
  module CompanyFetcherBot
    include OpencBot
    include OpencBot::Helpers::IncrementalSearch
    include OpencBot::Helpers::AlphaSearch
    include OpencBot::Helpers::Reporting

    STDOUT.sync = true
    STDERR.sync = true
    # This is called by #update_datum
    def fetch_datum(company_number, options = {})
      company_page = fetch_registry_page(company_number, options)
      { company_page: company_page }
    end

    def inferred_jurisdiction_code
      poss_j_code = name.sub(/CompaniesFetcher/, "").underscore
      poss_j_code[/^[a-z]{2}$|^[a-z]{2}_[a-z]{2}$/]
    end

    def primary_key_name
      :company_number
    end

    # This overrides default #save_entity (defined in RegisterMethods) and adds
    # the inferred jurisdiction_code, unless it is overridden in entity_info
    def save_entity(entity_info)
      return if entity_info.blank?

      default_options = { jurisdiction_code: inferred_jurisdiction_code }
      super(default_options.merge(entity_info))
    end

    def save_entity!(entity_info)
      return if entity_info.blank?

      default_options = { jurisdiction_code: inferred_jurisdiction_code }
      super(default_options.merge(entity_info))
    end

    # wraps #update_data with reporting so that methods can be overridden by company_fetchers
    # and reporting will still happen (also allows update_data to be run without reporting).
    def run(options = {})
      start_time = Time.now
      update_data_results = update_data(options.merge(started_at: start_time)) || {}
      # we may get a string back, or something else
      update_data_results = { output: update_data_results.to_s } unless update_data_results.is_a?(Hash)
      report_run_results(update_data_results.merge(started_at: start_time, ended_at: Time.now, status_code: "1"))
    end

    def schema_name
      super || "company-schema"
    end

    # this is what is called every time the bot is run using @my_bot.run, or more likely from
    # cron/command line using: bundle exec openc_bot rake bot:run
    # It should return some information to be included in the bot run report, and any
    # that is returned from fetch_data or update_stale (which you should override in preference to
    # overriding this method) will be included in the run report
    def update_data(options = {})
      fetch_data_results = fetch_data
      update_stale_results = update_stale
      res = {}
      res.merge!(fetch_data_results) if fetch_data_results.is_a?(Hash)
      res.merge!(update_stale_results) if update_stale_results.is_a?(Hash)
      res
    rescue Exception => e
      send_error_report(e, options)
      raise e
    end
  end
end
