# encoding: UTF-8
module OpencBot
  module Helpers
    module RegisterMethods

      def datum_exists?(uid)
        !!select("ocdata.#{primary_key_name} FROM ocdata WHERE #{primary_key_name} = '?' LIMIT 1", uid).first
      end

      def prepare_and_save_data(all_data,options={})
        data_to_be_saved = prepare_for_saving(all_data)
        insert_or_update([primary_key_name], data_to_be_saved)
      end

      def primary_key_name
        self.const_defined?('PRIMARY_KEY_NAME') ? self.const_get('PRIMARY_KEY_NAME') : :uid
      end

      # sensible default. Either uses computed version or registry_url in db
      def registry_url(uid)
        computed_registry_url(uid) || registry_url_from_db(uid)
      end

      # stub method. Override in including module if this can be computed from uid
      def computed_registry_url(uid)
      end

      # stub method. Override in including module if this can be pulled from db (i.e. it is stored there)
      def registry_url_from_db(uid)
      end

      def stale_entry_uids(stale_count=nil)
        stale_count ||= 1000
        sql_query = "ocdata.* from ocdata WHERE retrieved_at IS NULL OR strftime('%s', retrieved_at) < strftime('%s',  '#{Date.today - 30}') LIMIT #{stale_count.to_i}"
        raw_data = select(sql_query).each do |res|
          yield res[primary_key_name.to_s]
        end
      end

      def update_data
        fetch_data_via_incremental_search
        update_stale
        save_run_report(:status => 'success')
      end

      # This method updates a datum given by a uid (e.g. a company_number), by fetching new data, processing it
      # and then saving it. It assumes the methods for doing this (#fetch_datum and #process_datum) are implemented
      # in the module that includes this method.
      #
      # If no second argument is passed to this method, or false is passed, the
      # method will return the processed data hash
      # If true is passed as the second argument, the method will output the
      # updated result as json to STDOUT, which can then be consumed by, say,
      # something which triggered this method, for example if it was called by
      # a rake task, which in turn might have been called by the main
      # OpenCorporates application
      def update_datum(uid, output_as_json=false,replace_existing_data=false)
        return unless raw_data = fetch_datum(uid)
        processed_data = process_datum(raw_data).merge(primary_key_name => uid, :retrieved_at => Time.now.to_s)
        # prepare the data for saving (converting Arrays, Hashes to json) and
        # save the original data too, as we may not extracting everything from it yet
        prepare_and_save_data(processed_data.merge(:data => raw_data))
        if output_as_json
          puts processed_data.to_json
        else
          processed_data
        end
      rescue Exception => e
        output_json_error_message(e) if output_as_json
      end

      def update_stale(stale_count=nil)
        stale_entry_uids(stale_count) do |stale_entry_uid|
          update_datum(stale_entry_uid)
        end
      end

      private
      # This is a utility method for outputting an error message as json to STDOUT
      # (which can then be handled by the importer)
      def output_json_error_message(err_obj)
        err_msg = {'error' => {'klass' => err_obj.class.to_s, 'message' => err_obj.message, 'backtrace' => err_obj.backtrace}}
        puts err_msg.to_json
      end

      def prepare_for_saving(raw_data_hash)
        # deep clone hash
        prepared_data = Marshal.load( Marshal.dump(raw_data_hash) )
        #This jsonifies each value that is an an array or hash so that it can be saved as a string in sqlite
        prepared_data.each do |k,v|
          case v
          when Array, Hash
            prepared_data[k] = v.to_json
          end
        end
        prepared_data
      end

    end
  end
end