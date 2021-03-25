# frozen_string_literal: true

require "openc_bot/helpers/persistence_handler"
require "openc_bot/helpers/pseudo_machine_register_methods"

module OpencBot
  module Helpers
    # Fetching activities
    module PseudoMachineFetcher
      include OpencBot::Helpers::PsuedoMachineRegisterMethods
      include OpencBot::Helpers::PersistenceHandler

      def dataset_based
        const_defined?("DATASET_BASED") && const_get("DATASET_BASED")
      end

      def run(start_time = nil)
        fetch_data_results = fetch_data(start_time)
        # ignore stale for the moment
        # update_stale_results = update_stale
        res = {}
        res.merge!(fetch_data_results) if fetch_data_results.is_a?(Hash)
        res
      end

      def fetch_data_via_dataset(acq_start_time, fetch_start_time)
        # to be implemented by fetcher code that includes this
        # should persist data using persist(datum)
      end

      def fetch_data(acq_start_time = nil)
        fetch_start_time = Time.now.utc
        res = {}
        if use_alpha_search
          fetch_data_via_alpha_search
          res[:run_type] = "alpha"
        elsif dataset_based
          # handles the initial creation of the jsonl file for the "activity" (fetcher run)
          # "6056bb08-c8e6-451f-9bea-2bcac9067e49" is the machine's acquisition_id which
          # in reality we would supply a way to fetch or generate as required
          MachineBot::Fetching.create_run_jsonl_file("6056bb08-c8e6-451f-9bea-2bcac9067e49", acq_start_time, "fetching", fetch_start_time)
          fetch_data_via_dataset(acq_start_time, fetch_start_time)
          res[:run_type] = "dataset"
        else
          new_highest_numbers = fetch_data_via_incremental_search
          res[:run_type] = "incremental"
          res[:output] = "New highest numbers = #{new_highest_numbers.inspect}"
        end
        res.merge(fetched: records_processed, fetch_start: fetch_start_time, fetch_end: Time.now.utc)
      rescue OpencBot::OutOfPermittedHours, OpencBot::SourceClosedForMaintenance, Interrupt, SystemExit => e
        res.merge!({ fetch_data_output: { error: exception_to_object(e) } })
      rescue StandardError => e
        res.merge!({ fetch_data_error: { error: exception_to_object(e) } })
      end
    end
  end
end
