require "openc_bot/exceptions"
require "mail"

module OpencBot
  module Helpers
    # Methods for reporting start/end/progress/errors of bot runs
    # as emails and as data posted to the Analysis app.
    module Reporting
      # this is only available inside the VPN
      ANALYSIS_HOST = "https://analysis.opencorporates.com".freeze

      PROGRESS_REPORT_FREQUENCY = 5.minutes

      RUN_REPORT_PARAMS = %i[
        started_at
        ended_at
        status_code
        run_type
        output
      ].freeze

      def reporting_enabled?
        ENV["FETCHER_BOT_ENV"] == "production"
      end

      def report_run_results(results)
        send_run_report(results)
        report_run_to_analysis_app(results)
      end

      def send_error_report(exception, options = {})
        subject_details = options[:subject_details] || exception
        subject = "Error running #{name}: #{subject_details}"
        body = "Error details: #{exception.inspect}.\nBacktrace:\n#{exception.backtrace}"
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
        return unless reporting_enabled?

        Mail.deliver do
          from "admin@opencorporates.com"
          to "bots@opencorporates.com"
          subject params[:subject]
          body params[:body]
        end
      end

      def report_run_to_analysis_app(params)
        return unless reporting_enabled?

        bot_id = to_s.underscore
        run_params = params.slice!(RUN_REPORT_PARAMS)
        run_params.merge!(bot_id: bot_id, bot_type: "external", git_commit: current_git_commit, host: `hostname`.strip)
        run_params[:output] ||= params.to_s unless params.blank?
        _analysis_http_post("#{ANALYSIS_HOST}/runs", run: run_params)
      rescue StandardError => e
        puts "Exception (#{e.inspect}) reporting run to analysis app"
      end

      # DEPRECATED. Please use report_run_to_analysis_app instead of report_run_to_oc
      alias report_run_to_oc report_run_to_analysis_app

      def track_company_processed
        StatsD.increment("#{statsd_namespace}.processed", sample_rate: 1.0)

        increment_progress_counters(companies_processed_delta: 1)

        @last_reported_progress ||= Time.new(0)
        return unless Time.now > @last_reported_progress + PROGRESS_REPORT_FREQUENCY

        report_progress_to_analysis_app
        @last_reported_progress = Time.now
      end

      def increment_progress_counters(companies_processed_delta: nil)
        @processed_count ||= 0
        @processed_count += companies_processed_delta
      end

      def report_progress_to_analysis_app
        return unless reporting_enabled?

        data = {
          "bot_id" => to_s.underscore,
          "companies_processed" => @processed_count,
          "companies_added" => nil,
          "companies_updated" => nil,
        }
        _analysis_http_post("#{ANALYSIS_HOST}/fetcher_progress_log", data: data.to_json)
      rescue StandardError => e
        puts "Exception (#{e.inspect}) reporting progress to analysis app"
      end

      def _analysis_app_client
        @analysis_app_client ||= _client(connect_timeout: 5, receive_timeout: 10, flush_client: true)
      end

      def _analysis_http_post(url, params)
        _analysis_app_client.post(url, params.to_query)
      end
    end
  end
end
