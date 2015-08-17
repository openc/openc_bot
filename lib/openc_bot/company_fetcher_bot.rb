require 'openc_bot'
require 'openc_bot/helpers/incremental_search'
require 'openc_bot/helpers/alpha_search'
require 'openc_bot/asana_notifier'
require 'mail'


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

    def update_data(options={})
      fetch_data
      update_stale
      send_run_report
    rescue Exception => e
      send_error_report(e)
      raise e
    end

    private
    def mark_bot_as_failing_on_asana(exception)
      error_description = "Code for this bot: https://github.com/openc/external_bots/tree/master/#{inferred_jurisdiction_code}_companies_fetcher\nError details: #{exception.inspect}.\nBacktrace:\n#{exception.backtrace}"
      params = {
        :tag => inferred_jurisdiction_code,
        :asana_api_key => ASANA_API_KEY,
        :workspace => ASANA_WORKSPACE,
        :title => exception.message,
        :description => error_description
      }
      AsanaNotifier.create_failed_bot_task(params)
    end

    def send_error_report(e)
      subject = "Error running #{self.name}: #{e}"
      body = "Error details: #{e.inspect}.\nBacktrace:\n#{e.backtrace}"
      mark_bot_as_failing_on_asana(e) if ENV['CREATE_ASANA_TASKS_FOR_BOT_FAILURES']
      send_report(:subject => subject, :body => body)
    end

    def send_run_report
      subject = "#{self.name} successfully ran"
      db_filesize = File.size?(db_location)
      body = "No problems to report. db is #{db_location}, #{db_filesize} bytes. Last modified: #{File.stat(db_location).mtime}"
      send_report(:subject => subject, :body => body)
    end

    def send_report(params)
      Mail.deliver do
        from     'admin@opencorporates.com'
        to       'bots@opencorporates.com'
        subject  params[:subject]
        body     params[:body]
      end
    end


  end
end
