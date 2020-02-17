require "json-schema"
require "active_support"
require "active_support/core_ext"
require "openc_bot/exceptions"
require "retriable"
require "tzinfo"
require "English"

module OpencBot
  module Helpers
    module RegisterMethods # rubocop:disable Metrics/ModuleLength
      MAX_BUSY_RETRIES = 10

      def allowed_hours
        if const_defined?("ALLOWED_HOURS")
          const_get("ALLOWED_HOURS").to_a
        elsif const_defined?("TIMEZONE")
          # See https://en.wikipedia.org/wiki/List_of_tz_database_time_zones for definitions/examples
          # eg TIMEZONE = "America/Panama"
          (18..24).to_a + (0..8).to_a
        end
      end

      def use_alpha_search
        const_defined?("USE_ALPHA_SEARCH") && const_get("USE_ALPHA_SEARCH")
      end

      def current_git_commit
        `git log -1 --format="%H"`.strip
      end

      def current_time_in_zone
        if const_defined?("TIMEZONE")
          # See https://en.wikipedia.org/wiki/List_of_tz_database_time_zones for definitions/examples
          # eg TIMEZONE = "America/Panama"
          tz = TZInfo::Timezone.get(const_get("TIMEZONE"))
          tz.now
        else
          Time.now
        end
      end

      def datum_exists?(uid)
        !!select("ocdata.#{primary_key_name} FROM ocdata WHERE #{primary_key_name} = ? LIMIT 1", uid).first
      end

      def default_stale_count
        const_defined?("STALE_COUNT") ? const_get("STALE_COUNT") : 1000
      end

      # fetches and saves data. By default assumes an incremental search, or an alpha search
      # if USE_ALPHA_SEARCH is set. This method should be overridden if you are going to do a
      # different type of data import, e.g from a CSV file.
      def fetch_data
        original_count = record_count
        res = {}
        if use_alpha_search
          fetch_data_via_alpha_search
          res[:run_type] = "alpha"
        else
          new_highest_numbers = fetch_data_via_incremental_search
          res[:run_type] = "incremental"
          res[:output] = "New highest numbers = #{new_highest_numbers.inspect}"
        end
        records_added = record_count - original_count
        res.merge(added: records_added)
      end

      def export_data
        sql_query = "ocdata.* from ocdata"
        select(sql_query).each do |res|
          yield post_process(res, true)
        end
      end

      def fetch_registry_page(company_number, options = {})
        sleep_before_http_req
        _http_get(registry_url(company_number), options)
      end

      def in_prohibited_time?
        current_time = current_time_in_zone

        allowed_hours && !allowed_hours.include?(current_time.hour) && !current_time.saturday? && !current_time.sunday?
      end

      def prepare_and_save_data(all_data, _options = {})
        data_to_be_saved = prepare_for_saving(all_data)
        fail_count, retry_interval = 0, 5
        begin
          insert_or_update([primary_key_name], data_to_be_saved)
        rescue SQLite3::BusyException => e
          fail_count += 1
          if fail_count <= MAX_BUSY_RETRIES
            puts "#{e.inspect} raised saving:\n#{all_data}\n\n" if verbose?
            sleep retry_interval
            retry_interval *= 2
            retry
          else
            raise e
          end
        end
      end

      def primary_key_name
        const_defined?("PRIMARY_KEY_NAME") ? const_get("PRIMARY_KEY_NAME") : :uid
      end

      def raise_when_saving_invalid_record
        !!const_defined?("RAISE_WHEN_SAVING_INVALID_RECORD")
      end

      def record_count
        select("COUNT(#{primary_key_name}) as count from ocdata").first["count"]
      rescue StandardError
        0
      end

      # sensible default. Either uses computed version or registry_url in db
      def registry_url(uid)
        url = computed_registry_url(uid) || registry_url_from_db(uid)
        if url.nil?
          raise OpencBot::SingleRecordUpdateNotImplemented, "No registry_url provided"
        else
          url
        end
      end

      def save_raw_data_on_filesystem
        !!const_defined?("SAVE_RAW_DATA_ON_FILESYSTEM")
      end

      # stub method. Override in including module if this can be computed from uid
      def computed_registry_url(uid)
      end

      # stub method. Override in including module if this can be pulled from db (i.e. it is stored there)
      def registry_url_from_db(uid)
      end

      def save_entity(entity_datum)
        validation_errors = validate_datum(entity_datum.except(:data))
        return unless validation_errors.blank?

        prepare_and_save_data(entity_datum)
      end

      # Behaves like +save_entity+ but raises RecordInvalid exception if
      # record is not valid (validation errors are available in the
      # excpetion's +validation_errors+ method)
      def save_entity!(entity_datum)
        validation_errors = validate_datum(entity_datum.except(:data))
        raise OpencBot::RecordInvalid, validation_errors unless validation_errors.blank?

        prepare_and_save_data(entity_datum)
      end

      def schema_name
        const_defined?("SCHEMA_NAME") ? const_get("SCHEMA_NAME") : nil
      end

      def stale_entry_uids(stale_count = nil)
        stale_count ||= default_stale_count
        sql_query = "ocdata.#{primary_key_name} from ocdata WHERE retrieved_at IS NULL OR strftime('%s', retrieved_at) < strftime('%s',  '#{Date.today - days_till_stale}') order by datetime( retrieved_at ) LIMIT #{stale_count.to_i}"
        select(sql_query).each do |res|
          yield res[primary_key_name.to_s]
        end
      rescue SQLite3::SQLException => e
        if e.message[/no such column: retrieved_at/]
          sqlite_magic_connection.add_columns("ocdata", ["retrieved_at"])
          retry
        else
          raise e
        end
      end

      def get_raw_data(uid, format = nil)
        file_location = raw_data_file_location(uid, format)
        File.read(file_location) if File.exist?(file_location)
      end

      def days_till_stale
        const_defined?("DAYS_TILL_STALE") ? const_get("DAYS_TILL_STALE") : 30
      end

      def stale_entry?(uid)
        rec = select("retrieved_at from ocdata where #{primary_key_name}=?", uid).first
        return true if rec.nil? || rec["retrieved_at"].blank?

        !!(Date.parse(rec["retrieved_at"]) < (Date.today - days_till_stale))
      rescue SqliteMagic::NoSuchTable
        # don't worry -- just report as stale
        true
      end

      def save_raw_data(raw_data, uid, format = nil)
        file_location = raw_data_file_location(uid, format)
        File.open(file_location, "w") { |f| f.print raw_data }
      end

      def raw_data_file_location(uid, format = nil)
        normalised_uid = uid.to_s.gsub(/[^[[:alnum:]]]/, "")
        directory = File.join(*[root_directory, "data", normalised_uid.gsub(/^0+/, "").split(//).first(5)].flatten)
        FileUtils.mkdir_p(directory) unless Dir.exist?(directory)
        filename = format ? "#{normalised_uid}.#{format}" : normalised_uid
        File.join(directory, filename)
      end

      def update_data(_options = {})
        fetch_data
        update_stale
        save_run_report(status: "success")
      end

      # This method updates a datum given by a uid (e.g. a company_number), by fetching new data, processing it
      # and then saving it. It assumes the methods for doing this (#fetch_datum and #process_datum) are implemented
      # in the module that includes this method.
      #
      # If no second argument is passed to this method (i.e. called_externally is not
      # requested), or false is passed, the method will return the processed data hash.
      # If called_externally is true, the method will output the
      # updated result as json to STDOUT, which can then be consumed by, say,
      # something which triggered this method, for example if it was called by
      # a rake task, which in turn might have been called by the main
      # OpenCorporates application
      #
      # If the data to be saved is invalid then either the exception is raised,
      # or, if called_externally is true then the validation error is included
      # in the JSON error message
      #
      # Finally, unless called_externally is true, then fetch_datum (which actually
      # is what gets the data from the source) is called with
      # ignore_out_of_hours_settings as true
      def update_datum(uid, called_externally = false, _replace_existing_data = false)
        return unless raw_data = called_externally ? fetch_datum(uid, ignore_out_of_hours_settings: true) : fetch_datum(uid)

        default_options = { primary_key_name => uid, :retrieved_at => Time.now }
        # prepare the data for saving (converting Arrays, Hashes to json) and
        return unless base_processed_data = process_datum(raw_data)

        processed_data = default_options.merge(base_processed_data)
        # save the original data too, as we may not extracting everything from it yet
        data_for_saving_in_db = if save_raw_data_on_filesystem
                                  processed_data
                                else
                                  processed_data.merge(data: raw_data)
                                end
        if raise_when_saving_invalid_record
          save_entity!(data_for_saving_in_db)
        else
          save_entity(data_for_saving_in_db)
        end
        if called_externally
          puts processed_data.to_json
        else
          processed_data
        end
      rescue Exception => e
        if called_externally
          output_json_error_message(e)
        else
          rich_message = "#{e.message} updating entry with uid: #{uid}"
          puts rich_message if verbose?
          raise $ERROR_INFO, rich_message, $ERROR_INFO.backtrace
        end
      end

      def update_stale(stale_count = nil)
        count = 0
        records_updated_count = stale_entry_uids(stale_count) do |stale_entry_uid|
          update_datum(stale_entry_uid)
          count += 1
        end
        { updated: count }
      rescue OutOfPermittedHours, SourceClosedForMaintenance => e
        { updated: count, output: e.message }
      end

      def validate_datum(record)
        JSON::Validator.fully_validate(
          "#{schema_path}/#{schema_name}.json",
          record.to_json,
          errors_as_objects: true,
        )
      end

      def post_process(row_hash, skip_nulls = false)
        # many of the fields will be serialized json and so we convert to ruby objects
        convert_json_to_ruby(row_hash.except(:data), skip_nulls)
      end

      def schema_path
        File.expand_path("../../../schemas/schemas", __dir__)
      end

      private

      # This is a utility method for outputting an error message as json to STDOUT
      # (which can then be handled by the importer)
      def output_json_error_message(err_obj)
        err_msg = { "error" => { "klass" => err_obj.class.to_s, "message" => err_obj.message, "backtrace" => err_obj.backtrace } }
        puts err_msg.to_json
      end

      def prepare_for_saving(raw_data_hash)
        prepared_data = deep_clone_hash(raw_data_hash)
        # This jsonifies each value that is an an array or hash so that it can be saved as a string in sqlite
        prepared_data.each do |k, v|
          case v
          when Array, Hash
            prepared_data[k] = v.to_json
          when Date, Time, DateTime
            prepared_data[k] = v.iso8601
          end
        end
        prepared_data
      end

      def sleep_before_http_req
        if const_defined?("SLEEP_BEFORE_HTTP_REQ")
          sleep_time = const_get("SLEEP_BEFORE_HTTP_REQ")
          puts "#{name} about to sleep for #{sleep_time} before fetching data. Time now: #{Time.now}" if verbose?
          sleep(sleep_time)
          puts "#{name} slept for #{sleep_time}: Time now #{Time.now}" if verbose?
        end
      end

      def _client(options = {})
        return @client if @client && !(options[:flush_client])

        @client = HTTPClient.new(options.delete(:proxy))
        @client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE if options.delete(:skip_ssl_verification)
        @client.agent_name = options.delete(:user_agent)
        @client.connect_timeout = options.delete(:connect_timeout)
        @client.receive_timeout = options.delete(:receive_timeout)
        @client.ssl_config.ssl_version = options.delete(:ssl_version) if options[:ssl_version]
        if ssl_certificate = options.delete(:ssl_certificate)
          @client.ssl_config.add_trust_ca(ssl_certificate) # Above cert
        end
        @client
      end

      def _http_get(url, options = {})
        raise OutOfPermittedHours, "Request at #{Time.now} is not out business hours (#{allowed_hours})" if options[:restrict_to_out_of_hours] && in_prohibited_time?

        _client(options).get_content(url)
      end

      def _http_get_with_retry(url, options = {})
        log_info = proc do |exception, tries|
          warn("Retrying #{url} because of #{exception.class}: '#{exception.message}' - #{tries} attempts.")
        end
        tries = options.delete(:tries) || 5
        base_interval = options.delete(:tries) || 5
        Retriable.retriable on: [SystemCallError, SocketError, EOFError, HTTPClient::BadResponseError, HTTPClient::ReceiveTimeoutError, HTTPClient::ConnectTimeoutError, Errno::ETIMEDOUT],
                            tries: tries,
                            base_interval: base_interval,
                            on_retry: log_info do
          _http_get(url, options)
        end
      end

      def deep_clone_hash(given_hash)
        Marshal.load(Marshal.dump(given_hash))
      end

      def convert_json_to_ruby(data_hash, skip_nulls = false)
        data_hash.each do |k, v|
          begin
            parsed_data = JSON.parse(v) if v.is_a?(String) && v[/^[\{\[]+\"|^\[\]$|^{}$/]
          rescue StandardError
            v
          end
          case parsed_data
          when Hash
            parsed_data = parsed_data.with_indifferent_access
          when Array
            parsed_data.collect! { |e| e.is_a?(Hash) ? e.with_indifferent_access : e }
          end
          if skip_nulls && v.nil?
            data_hash.delete(k)
          else
            data_hash[k] = parsed_data if parsed_data
          end
        end
      end
    end
  end
end
