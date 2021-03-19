# frozen_string_literal: true

require "openc_bot/helpers/register_methods"
module OpencBot
  module Helpers
    # Extending the behaviour for the CompanyFetcherBot
    module RegisterMethodsV1
      include OpencBot::Helpers::RegisterMethods

      def dataset_based
        const_defined?("DATASET_BASED") && const_get("DATASET_BASED")
      end

      def update_stale(stale_count = nil)
        count = 0
        stale_entry_uids(stale_count) do |stale_entry_uid|
          update_datum(stale_entry_uid)
          count += 1
        end
        { updated: count, stale: assess_stale }
      rescue OpencBot::OutOfPermittedHours, OpencBot::SourceClosedForMaintenance, Interrupt, SystemExit => e
        { updated: count, stale: assess_stale, update_stale_output: { error: exception_to_object(e) } }
      rescue StandardError => e
        { updated: count, stale: assess_stale, update_stale_error: { error: exception_to_object(e) } }
      end

      def fetch_data
        original_count = record_count
        res = {}
        if use_alpha_search
          fetch_data_via_alpha_search
          res[:run_type] = "alpha"
        elsif dataset_based
          fetch_data_via_dataset
          res[:run_type] = "dataset"
        else
          new_highest_numbers = fetch_data_via_incremental_search
          res[:run_type] = "incremental"
          res[:output] = "New highest numbers = #{new_highest_numbers.inspect}"
        end
        records_added = record_count - original_count
        res.merge(added: records_added)
      rescue OpencBot::OutOfPermittedHours, OpencBot::SourceClosedForMaintenance, Interrupt, SystemExit => e
        res.merge!({ fetch_data_output: { error: exception_to_object(e) } })
      rescue StandardError => e
        res.merge!({ fetch_data_error: { error: exception_to_object(e) } })
      end

      def exception_to_object(exp)
        { klass: exp.class.to_s, message: exp.message, backtrace: exp.backtrace }
      end
    end
  end
end
