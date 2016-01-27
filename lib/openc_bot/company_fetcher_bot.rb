require 'openc_bot'
require 'openc_bot/helpers/incremental_search'
require 'openc_bot/helpers/alpha_search'
# require 'openc_bot/asana_notifier'
require 'mail'


module OpencBot
  module CompanyFetcherBot
    include OpencBot
    include OpencBot::Helpers::IncrementalSearch
    include OpencBot::Helpers::AlphaSearch
    # this is only available inside the VPN
    OC_RUN_REPORT_URL = 'https://opencorporates.internal/runs'

    STDOUT.sync = true
    STDERR.sync = true
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

    def update_data(options={})
      fetch_data_results = fetch_data
      update_stale
      send_run_report(options.merge(fetch_data_results||{}))
    rescue Exception => e
      send_error_report(e)
      raise e
    end

    private
    def mark_bot_as_failing_on_asana(exception)
      # error_description = "Code for this bot: https://github.com/openc/external_bots/tree/master/#{inferred_jurisdiction_code}_companies_fetcher\nError details: #{exception.inspect}.\nBacktrace:\n#{exception.backtrace}"
      # params = {
      #   :tag => inferred_jurisdiction_code,
      #   :asana_api_key => ENV['ASANA_API_KEY'],
      #   :workspace => ENV['ASANA_WORKSPACE'],
      #   :title => exception.message,
      #   :description => error_description
      # }
      # AsanaNotifier.create_failed_bot_task(params)
    end

    def send_error_report(e)
      subject = "Error running #{self.name}: #{e}"
      body = "Error details: #{e.inspect}.\nBacktrace:\n#{e.backtrace}"
      send_report(:subject => subject, :body => body)
      report_run_to_oc(:output => body, :status_code => '0', :ended_at => Time.now.to_s)
    end

    def send_run_report(run_results=nil)
      subject = "#{self.name} successfully ran"
      db_filesize = File.size?(db_location)
      body = "No problems to report. db is #{db_location}, #{db_filesize} bytes. Last modified: #{File.stat(db_location).mtime}"
      body += "\nRun results = #{run_results.inspect}" unless run_results.blank?
      send_report(:subject => subject, :body => body)
      report_run_to_oc(:output => body, :status_code => '1', :ended_at => Time.now.to_s)
    end

    def send_report(params)
      Mail.deliver do
        from     'admin@opencorporates.com'
        to       'bots@opencorporates.com'
        subject  params[:subject]
        body     params[:body]
      end
    end

    def report_run_to_oc(params)
      bot_id = self.to_s.underscore
      run_params = params.merge(:bot_id => bot_id, :bot_type => 'external')
      # this will (correctly) fail in test and development as it will be outside internal IP range
      _client.post(OC_RUN_REPORT_URL, {:run => run_params}.to_query)
    rescue Exception => e
      puts "Exception (#{e.inspect}) reporting run to OpenCorporates"
    end


  end
end
