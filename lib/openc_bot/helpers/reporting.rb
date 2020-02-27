require "openc_bot/exceptions"
require "mail"

module OpencBot
  module Helpers
    module Reporting

      # this is only available inside the VPN
      ANALYSIS_HOST = "https://analysis.opencorporates.com".freeze

      RUN_ATTRIBUTES = %i[
        started_at
        ended_at
        status_code
        run_type
        output
      ].freeze

      def report_run_results(results)
        send_run_report(results)
        report_run_to_analysis_app(results)
      end

      def report_run_progress(companies_processed:, companies_added: nil, companies_updated: nil)
        report_progress_to_analysis_app(companies_processed: companies_processed, companies_added: companies_added, companies_updated: companies_updated)
      end

      def send_error_report(e, options = {})
        subject = "Error running #{name}: #{e}"
        body = "Error details: #{e.inspect}.\nBacktrace:\n#{e.backtrace}"
        send_report(subject: subject, body: body)
        report_run_to_analysis_app(output: body, status_code: "0", ended_at: Time.now.to_s, started_at: options[:started_at])
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

      def report_run_to_analysis_app(params)
        bot_id = to_s.underscore
        run_params = params.slice!(RUN_ATTRIBUTES)
        run_params.merge!(bot_id: bot_id, bot_type: "external", git_commit: current_git_commit)
        run_params[:output] ||= params.to_s unless params.blank?
        _http_post("#{ANALYSIS_HOST}/runs", run: run_params)
      rescue Exception => e
        puts "Exception (#{e.inspect}) reporting run to analysis app"
      end

      # DEPRECATED. Please use report_run_to_analysis_app instead of report_run_to_oc
      alias report_run_to_oc report_run_to_analysis_app

      def report_progress_to_analysis_app(companies_processed:, companies_added: nil, companies_updated: nil)
        data = {
          "bot_id" => to_s.underscore,
          "companies_processed" => companies_processed,
          "companies_added" => companies_added,
          "companies_updated" => companies_updated,
        }
        _http_post("#{ANALYSIS_HOST}/fetcher_progress_log", data: data.to_json)
      rescue Exception => e
        puts "Exception (#{e.inspect}) reporting progress to analysis app"
      end

      def _analysis_app_client
        @analysis_app_client ||= _client(connect_timeout: 5, receive_timeout: 10, flush_client: true)
      end

      def _http_post(url, params)
        _analysis_app_client.post(url, params.to_query)
      end
    end
  end
end
