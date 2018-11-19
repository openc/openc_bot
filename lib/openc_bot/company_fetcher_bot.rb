require "openc_bot"
require "openc_bot/helpers/incremental_search"
require "openc_bot/helpers/alpha_search"
# require 'openc_bot/asana_notifier'
require "mail"

module OpencBot
  module CompanyFetcherBot
    include OpencBot
    include OpencBot::Helpers::IncrementalSearch
    include OpencBot::Helpers::AlphaSearch
    # this is only available inside the VPN
    OC_RUN_REPORT_URL = "https://opencorporates.com/runs".freeze
    RUN_ATTRIBUTES = %i[
      started_at
      ended_at
      status_code
      run_type
      output
    ].freeze

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

    def report_run_results(results)
      send_run_report(results)
      report_run_to_oc(results)
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

    private

    def send_error_report(e, options = {})
      subject = "Error running #{name}: #{e}"
      body = "Error details: #{e.inspect}.\nBacktrace:\n#{e.backtrace}"
      send_report(subject: subject, body: body)
      report_run_to_oc(output: body, status_code: "0", ended_at: Time.now.to_s, started_at: options[:started_at])
    end

    def send_run_report(run_results = nil)
      subject = "#{name} successfully ran"
      db_filesize = File.size?(db_location)
      body = "No problems to report. db is #{db_location}, #{db_filesize} bytes. Last modified: #{File.stat(db_location).mtime}"
      body += "\nRun results = #{run_results.inspect}" unless run_results.blank?
      send_report(subject: subject, body: body)
    end

    def send_report(params)
      Mail.deliver do
        from "admin@opencorporates.com"
        to "bots@opencorporates.com"
        subject params[:subject]
        body params[:body]
      end
    end

    def report_run_to_oc(params)
      bot_id = to_s.underscore
      run_params = params.slice!(RUN_ATTRIBUTES)
      run_params.merge!(bot_id: bot_id, bot_type: "external", git_commit: current_git_commit)
      run_params[:output] ||= params.to_s unless params.blank?
      _http_post(OC_RUN_REPORT_URL, run: run_params)
    rescue Exception => e
      puts "Exception (#{e.inspect}) reporting run to OpenCorporates"
    end

    def _http_post(_url, params)
      # this will (correctly) fail in development as it will be outside internal IP range
      _client.post(OC_RUN_REPORT_URL, params.to_query)
    end
  end
end
