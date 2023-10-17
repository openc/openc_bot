# frozen_string_literal: true

require "openc_bot/helpers/register_methods"

module OpencBot
  module Helpers
    module IncrementalSearch
      include OpencBot::Helpers::RegisterMethods

      # Gets new records using an incremental search
      def fetch_data_via_incremental_search(options = {})
        return unless old_highest_numbers = options.delete(:highest_entry_uids) || highest_entry_uids

        # offset by rewind count if set and also in that case assume by default we want to skip_existing_companies
        options = { offset: (0 - incremental_rewind_count), skip_existing_entries: true }.merge(options) if incremental_rewind_count
        new_highest_numbers = old_highest_numbers.collect do |old_highest_number|
          incremental_search(old_highest_number, options)
        end
        save_var(:highest_entry_uids, new_highest_numbers)
        new_highest_numbers
      end

      def fetch_gaps
        $stderr.puts "#{Time.now.utc.iso8601} - Starting fetch_gaps"
        current_number = nil 
        gap_count = 0
        save_var("lowest_company_number", lowest_company_number) if get_var("lowest_company_number").nil?
        gap_uid = get_var("highest_gap_uid") || get_var("lowest_company_number")
        highest_uid = get_var("highest_entry_uids")
        current_number = gap_uid
    
        loop do
          save_var(:highest_gap_uid, get_var("lowest_company_number"), nil) && break if current_number.to_i >= highest_uid.first.to_i
          break if gap_count > max_gap_count
          if datum_exists?(current_number)
            $stderr.puts "#{current_number} exists in the database"
          elsif update_datum(current_number, false)
            @added +=1
          else 
            puts "Failed to find company with uid #{current_number}."
          end
          save_var(:highest_gap_uid, current_number)
          current_number = increment_number(current_number)
          gap_count +=1
        end
        {
          gap_output: "New gap highest numbers = #{current_number}"
        }
      end

      def highest_entry_uids(force_get = false)
        bad_results = []
        results = get_var("highest_entry_uids")
        if force_get || results.nil? || results.empty? || (results.is_a?(Array) && results.any? { |r| r.nil? || r.empty? })
          results = entity_uid_prefixes.collect do |prefix|
            hcn = highest_entry_uid_result(prefix: prefix)
            bad_results << prefix if hcn.nil? || hcn.empty?
            hcn
          end
        end
        results.compact! unless bad_results.empty?
        return results unless results.empty?
      end

      def highest_entry_uid_result(options = {})
        sql_query = if options[:prefix]
                      ["ocdata.#{primary_key_name} FROM ocdata WHERE #{primary_key_name} LIKE ? ORDER BY cast(substr(#{primary_key_name},?) as real) DESC LIMIT 1", ["#{options[:prefix]}%", options[:prefix].length + 1]]
                    elsif options[:suffix]
                      ["ocdata.#{primary_key_name} FROM ocdata WHERE #{primary_key_name} LIKE ? ORDER BY cast(#{primary_key_name} as real) DESC LIMIT 1", "%#{options[:suffix]}"]
                    else
                      "ocdata.#{primary_key_name} FROM ocdata ORDER BY cast(#{primary_key_name} as real) DESC LIMIT 1"
                    end
        select(*sql_query).first[primary_key_name.to_s] # rescue nil
      rescue SqliteMagic::NoSuchTable
        # first run, so no table or database yet
        "#{options[:prefix]}0"
      end

      def incremental_rewind_count
        const_defined?("INCREMENTAL_REWIND_COUNT") ? const_get("INCREMENTAL_REWIND_COUNT") : nil
      end

      def entity_uid_prefixes
        const_defined?("ENTITY_UID_PREFIXES") ? const_get("ENTITY_UID_PREFIXES") : [nil]
      end

      def entity_uid_suffixes
        const_defined?("ENTITY_UID_SUFFIXES") ? const_get("ENTITY_UID_SUFFIXES") : [nil]
      end

      def incremental_search(uid, options = {})
        first_number = uid.dup
        current_number = nil # set up ouside of loop
        error_count = 0
        last_good_co_no = nil
        skip_existing_entries = options.delete(:skip_existing_entries)
        # start at given number but offset by given amount. i.e. by offset
        uid = increment_number(uid, options[:offset]) if options[:offset]
        loop do
          current_number = uid
          if skip_existing_entries && datum_exists?(uid)
            uid = increment_number(uid)
            error_count = 0 # reset error count
            next
          elsif update_datum(current_number, false)
            last_good_co_no = current_number
            error_count = 0 # reset error count
          else
            error_count += 1
            puts "Failed to find company with uid #{current_number}. Error count: #{error_count}" if verbose?
            break if error_count > max_failed_count
          end
          uid = increment_number(uid)
        end
        # return orig uid if we haven't had any new entities
        last_good_co_no ? last_good_co_no.to_s : first_number
      end

      def increment_number(uid, increment_amount = 1)
        orig_uid = uid.to_s.dup
        uid.to_s.sub(/\d+/) do |d|
          length = d.length
          incremented_number = d.to_i + increment_amount
          length = d.length
          length = incremented_number.to_s.length if increment_amount.negative? && !(d[/^0/])
          format("%0#{length}d", incremented_number)
        end
      end

      def max_failed_count
        const_defined?("MAX_FAILED_COUNT") ? const_get("MAX_FAILED_COUNT") : 10
      end

      def max_gap_count
        const_defined?("MAX_GAP_COUNT") ? const_get("MAX_GAP_COUNT") : 100000
      end

      def lowest_company_number
        const_defined?("LOWEST_COMPANY_NUMBER") ? const_get("LOWEST_COMPANY_NUMBER") : 0
      end
    end
  end
end
