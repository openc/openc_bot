# encoding: UTF-8
require 'json-schema'
require 'active_support'
require 'active_support/core_ext'
require 'openc_bot/exceptions'

module OpencBot
  module Helpers
    module RegisterMethods
      MAX_BUSY_RETRIES = 3

      def use_alpha_search
        self.const_defined?('USE_ALPHA_SEARCH') && self.const_get('USE_ALPHA_SEARCH')
      end

      def datum_exists?(uid)
        !!select("ocdata.#{primary_key_name} FROM ocdata WHERE #{primary_key_name} = ? LIMIT 1", uid).first
      end

      def default_stale_count
        self.const_defined?('STALE_COUNT') ? self.const_get('STALE_COUNT') : 1000
      end

      # fetches and saves data. By default assumes an incremental search, or an alpha search
      # if USE_ALPHA_SEARCH is set. This method should be overridden if you are going to do a
      # different type of data import, e.g from a CSV file.
      def fetch_data
        if use_alpha_search
          fetch_data_via_alpha_search
        else
          fetch_data_via_incremental_search
        end
      end

      def export_data
        sql_query = "ocdata.* from ocdata"
        select(sql_query).each do |res|
          yield post_process(res, true)
        end
      end

      def fetch_registry_page(company_number)
        sleep_before_http_req
        _client.get_content(registry_url(company_number))
      end

      def prepare_and_save_data(all_data,options={})
        data_to_be_saved = prepare_for_saving(all_data)
        # fail_count, retry_interval = 0, 5
        begin
          insert_or_update([primary_key_name], data_to_be_saved)
        rescue SQLite3::BusyException => e
          # fail_count += 1
          # if fail_count <= MAX_BUSY_RETRIES
          $stderr.puts "#{e.inspect} raised saving:\n#{all_data}\n\n" if verbose?
          #   sleep retry_interval
          #   retry_interval = retry_interval * 2
          #   retry
          # else
          raise e
          # end
        end

      end

      def primary_key_name
        self.const_defined?('PRIMARY_KEY_NAME') ? self.const_get('PRIMARY_KEY_NAME') : :uid
      end

      def raise_when_saving_invalid_record
        !!self.const_defined?('RAISE_WHEN_SAVING_INVALID_RECORD')
      end

      # sensible default. Either uses computed version or registry_url in db
      def registry_url(uid)
        url = computed_registry_url(uid) || registry_url_from_db(uid)
        if url.nil?
          raise OpencBot::SingleRecordUpdateNotImplemented.new(
                  "No registry_url provided")
        else
          url
        end
      end

      def save_raw_data_on_filesystem
        !!self.const_defined?('SAVE_RAW_DATA_ON_FILESYSTEM')
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
        raise OpencBot::RecordInvalid.new(validation_errors) unless validation_errors.blank?
        prepare_and_save_data(entity_datum)
      end

      def schema_name
        self.const_defined?('SCHEMA_NAME') ? self.const_get('SCHEMA_NAME') : nil
      end

      def stale_entry_uids(stale_count=nil)
        stale_count ||= default_stale_count
        sql_query = "ocdata.* from ocdata WHERE retrieved_at IS NULL OR strftime('%s', retrieved_at) < strftime('%s',  '#{Date.today - 30}') LIMIT #{stale_count.to_i}"
        raw_data = select(sql_query).each do |res|
          yield res[primary_key_name.to_s]
        end
      rescue SQLite3::SQLException => e
        if e.message[/no such column: retrieved_at/]
          sqlite_magic_connection.add_columns('ocdata', ['retrieved_at'])
          retry
        else
          raise e
        end
      end

      def get_raw_data(uid, format=nil)
        file_location = raw_data_file_location(uid, format)
        File.read(file_location) if File.exist?(file_location)
      end

      def save_raw_data(raw_data, uid, format=nil)
        file_location = raw_data_file_location(uid, format)
        File.open(file_location, 'w') { |f| f.print raw_data }
      end

      def raw_data_file_location(uid, format=nil)
        normalised_uid = uid.to_s.gsub(/[^[[:alnum:]]]/,'')
        directory = File.join(*([root_directory,'data',normalised_uid.gsub(/^0+/,'').split(//).first(5)].flatten))
        FileUtils.mkdir_p(directory) unless Dir.exist?(directory)
        filename = format ? "#{normalised_uid}.#{format}" : normalised_uid
        File.join(directory, filename)
      end

      def update_data(options={})
        fetch_data
        update_stale
        save_run_report(:status => 'success')
      end

      # This method updates a datum given by a uid (e.g. a company_number), by fetching new data, processing it
      # and then saving it. It assumes the methods for doing this (#fetch_datum and #process_datum) are implemented
      # in the module that includes this method.
      #
      # If no second argument is passed to this method (i.e. output_as_json is not
       # requested), or false is passed, the method will return the processed data hash.
      # If true is passed as the second argument, the method will output the
      # updated result as json to STDOUT, which can then be consumed by, say,
      # something which triggered this method, for example if it was called by
      # a rake task, which in turn might have been called by the main
      # OpenCorporates application
      #
      # If the data to be saved is invalid then either the exception is raised,
      # or, if output_as_json is requested then the validation error is included
      # in the JSON error message
      def update_datum(uid, output_as_json=false,replace_existing_data=false)
        return unless raw_data = fetch_datum(uid)
        default_options = {primary_key_name => uid, :retrieved_at => Time.now}
        # prepare the data for saving (converting Arrays, Hashes to json) and
        return unless base_processed_data = process_datum(raw_data)
        processed_data = default_options.merge(base_processed_data)
        # save the original data too, as we may not extracting everything from it yet
        if save_raw_data_on_filesystem
          data_for_saving_in_db = processed_data
        else
          data_for_saving_in_db = processed_data.merge(:data => raw_data)
        end
        if raise_when_saving_invalid_record
          save_entity!(data_for_saving_in_db)
        else
          save_entity(data_for_saving_in_db)
        end
        if output_as_json
          $stdout.puts processed_data.to_json
        else
          processed_data
        end
      rescue Exception => e
        if output_as_json
          output_json_error_message(e)
        else
          rich_message = "#{e.message} updating entry with uid: #{uid}"
          $stderr.puts rich_message if verbose?
          raise $!, rich_message, $!.backtrace
        end
      end

      def update_stale(stale_count=nil)
        stale_entry_uids(stale_count) do |stale_entry_uid|
          update_datum(stale_entry_uid)
        end

      end

      def validate_datum(record)
        Dir.chdir(schema_path) do
          JSON::Validator.fully_validate(
            "#{schema_name}.json",
            record.to_json,
            {:errors_as_objects => true}
          )
        end
      end

      def post_process(row_hash, skip_nulls=false)
        # many of the fields will be serialized json and so we convert to ruby objects
        convert_json_to_ruby(row_hash.except(:data), skip_nulls)
      end

      def schema_path
        File.expand_path('../../../../schemas/schemas', __FILE__)
      end

      private
      # This is a utility method for outputting an error message as json to STDOUT
      # (which can then be handled by the importer)
      def output_json_error_message(err_obj)
        err_msg = {'error' => {'klass' => err_obj.class.to_s, 'message' => err_obj.message, 'backtrace' => err_obj.backtrace}}
        $stderr.puts err_msg.to_json
      end

      def prepare_for_saving(raw_data_hash)
        prepared_data = deep_clone_hash(raw_data_hash)
        #This jsonifies each value that is an an array or hash so that it can be saved as a string in sqlite
        prepared_data.each do |k,v|
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
        if self.const_defined?('SLEEP_BEFORE_HTTP_REQ')
          sleep_time = self.const_get('SLEEP_BEFORE_HTTP_REQ')
          $stderr.puts "#{self.name} about to sleep for #{sleep_time} before fetching data. Time now: #{Time.now}" if verbose?
          sleep(sleep_time)
          $stderr.puts "#{self.name} slept for #{sleep_time}: Time now #{Time.now}" if verbose?
        end
      end

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

      def deep_clone_hash(given_hash)
        Marshal.load( Marshal.dump(given_hash) )
      end

      def convert_json_to_ruby(data_hash, skip_nulls=false)
        data_hash.each do |k,v|
          parsed_data = JSON.parse(v) if v.is_a?(String) && v[/^[\{\[]+\"|^\[\]$|^{}$/] rescue v
          case parsed_data
          when Hash
            parsed_data = parsed_data.with_indifferent_access
          when Array
            parsed_data.collect!{ |e| e.is_a?(Hash) ? e.with_indifferent_access : e  }
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
