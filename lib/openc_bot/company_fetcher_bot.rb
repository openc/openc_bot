# frozen_string_literal: true

require "openc_bot"
require "openc_bot/helpers/incremental_search"
require "openc_bot/helpers/alpha_search"
require "openc_bot/helpers/reporting"
require "tempfile"

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
      poss_j_code[/^[a-z]{2}\d?$|^[a-z]{2}_[a-z]{2}\d?$/]
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

    # This is the main method for running the bot. It is called by cron or
    # command line using: `bundle exec openc_bot rake bot:run`
    # It calls #update_data then reports the run result. #update_data might be
    # overridden by company_fetchers and the final run report will still happen.
    # Reporting is disabled anyway when FETCHER_BOT_ENV is development/test.
    def run(options = {})
      begin
        ingest_file = false
        start_time = Time.now
        update_data_results = {}
        is_parakeet_bot = self.singleton_class.ancestors
          .map { |m| m.name }
          .include?("OpencBot::PseudoMachineCompanyFetcherBot")
        LOGGER.info({service: "company_fetcher_bot", event:"run_begin", bot_name: bot_name, bot_run_id: bot_run_id}.to_json)
        begin
          update_data_results = update_data(options.merge(started_at: start_time)) || {}
          ok = true
          error = nil
        rescue Exception => e
          # Catch all to log outcome and upload any files that can be digested.
          ok = false
          error = e
        end
        # update_data_results = nil
        end_time = Time.now
        LOGGER.info({service: "company_fetcher_bot", event:"update_data_end",  ok: ok, bot_name: bot_name, bot_run_id: bot_run_id, duration_s: "#{(end_time - start_time).round(2)}s"}.to_json)
        # pass `SAVE_DATA_TO_S3` to enable uploading the file to S3
        if ENV["SAVE_DATA_TO_S3"]
          # PseudoMachineCompanyFetcherBot will add "data_directory" to the result in end.
          if is_parakeet_bot && update_data_results.has_key?( :data_directory)
            cut_off_epoch = (ENV["INGESTION_CUT_OFF_EPOCH"] || in_progress_acquisition_id).to_i # Default to only upload current run.
            loop do
              matching_dirs = get_pending_ingestion_dirs(acquisition_base_directory, cut_off_epoch)
              break if matching_dirs.empty? # Stop if no matching directories are left

              matching_dir = matching_dirs.first # Take the oldest matching directory
              bot_output_location = "#{matching_dir}/transformer.jsonl"
              unix_time_stamp = File.basename(matching_dir).to_i # Extract subdirectory name as unix_time_stamp

              if unix_time_stamp == 0
                raise "Invalid matching_dir name, expected epoch time (#{File.basename(matching_dir)})"
              end

              s3_date_folder_prefix = Time.at(unix_time_stamp).utc.strftime("%Y/%m/%d")
              s3_prefix = "external_bots/#{inferred_jurisdiction_code}/transformer/#{s3_date_folder_prefix}/#{inferred_jurisdiction_code}_transformer_#{unix_time_stamp}.jsonl.gz"
              gz_file_location = "#{matching_dir}/transformer.jsonl.gz"

              compress_file(bot_output_location, gz_file_location)
              upload_file_to_s3(ENV["S3_BUCKET_NAME"], s3_prefix, gz_file_location)
              rename_to_archive(matching_dir) # Archive the processed directory
            end

          elsif !is_parakeet_bot
            bot_output_location = "#{db_location}"
            unix_time_stamp = end_time.to_i
            s3_date_folder_prefix = DateTime.parse(end_time.to_s).strftime("%Y/%m/%d")
            s3_prefix = "external_bots/#{inferred_jurisdiction_code}/db/#{s3_date_folder_prefix}/#{inferred_jurisdiction_code}_db_#{unix_time_stamp}.db.gz"
            Tempfile.create(["#{inferred_jurisdiction_code}.", ".gz"]) do |tmp_file|
              compress_file(bot_output_location, tmp_file.path)
              upload_file_to_s3(ENV["S3_BUCKET_NAME"], s3_prefix, tmp_file.path)
            end
          end
        end

        update_data_results = { output: update_data_results.to_s } unless update_data_results.is_a?(Hash)
        report_run_results(update_data_results.merge(started_at: start_time, ended_at: Time.now, status_code: "1"))

        raise error unless error.nil?
        LOGGER.info({service: "company_fetcher_bot", event:"run_end", ok: ok, bot_name: bot_name, bot_run_id: bot_run_id, duration_s: "#{(Time.now - start_time).round(2)}s"}.to_json)

        update_data_results
      rescue Exception => e
        LOGGER.error({service: "company_fetcher_bot", event:"run_error", duration_s: (Time.now - start_time).round(2), bot_name: bot_name, bot_run_id: bot_run_id, message: e.message}.to_json)
        raise e
      end
    end

    def schema_name
      super || "company-schema"
    end

    # Outline bot run logic. Any information that is returned from #fetch_data
    # or #update_stale (which you should override in preference to overriding
    # this method) will be returned here and included in the final run report.
    def update_data(options = {})
      start_time = Time.now
      LOGGER.info({service: "company_fetcher_bot", event:"update_data_begin", bot_name: bot_name, bot_run_id: bot_run_id, }.to_json)
      fetch_data_results = fetch_data
      update_stale_results = update_stale
      res = {}
      res.merge!(fetch_data_results) if fetch_data_results.is_a?(Hash)
      res.merge!(update_stale_results) if update_stale_results.is_a?(Hash)
      LOGGER.info({service: "company_fetcher_bot", event:"update_data_end", bot_name: bot_name, bot_run_id: bot_run_id, ok: true, duration_s: (Time.now - start_time).round(2)}.to_json)
      res
    rescue Exception => e
      send_error_report(e, options)
      raise e
    end
  end
end
