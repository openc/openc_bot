# frozen_string_literal: true

module OpencBot
  module Helpers
    # Persistence handler for bot activities
    module PersistenceHandler
      def input_stream
        # override in segment bots
      end

      def output_stream
        name.to_s[/[A-Z][a-z]+$/].downcase
      end

      def acquisition_base_directory
        ENV["ACQUISITION_BASE_DIRECTORY"] || "data"
      end

      def acquisition_id
        @acquisition_id ||= (ENV["ACQUISITION_ID"] || in_progress_acquisition_id || Time.now.to_i)
      end

      # gets the most recent in progress acquisition id, based on in processing
      # directories
      def in_progress_acquisition_id
        return @acquisition_id unless @acquisition_id.blank?

        in_progress_acquisitions = Dir.glob("#{acquisition_base_directory}/*_processing").sort
        return if in_progress_acquisitions.empty?

        in_progress_acquisitions.last.split("/").last.sub("_processing", "")
      end

      def input_file_location
        File.join(acquisition_directory_processing, "#{input_stream}.jsonl")
      end

      def output_file_location
        File.join(acquisition_directory_processing, "#{output_stream}.jsonl")
      end

      def acquisition_directory_processing
        processing_directory = ENV["ACQUISITION_DIRECTORY"] || File.join(acquisition_base_directory, "#{acquisition_id}_processing")
        FileUtils.mkdir(processing_directory) unless Dir.exist?(processing_directory)
        processing_directory
      end

      def acquisition_directory_final
        File.join(acquisition_base_directory, in_progress_acquisition_id)
      end

      def records_processed
        `wc -l "#{output_file_location}"`.strip.split[0].to_i
      end

      def input_data
        File.foreach(input_file_location) do |line|
          yield JSON.parse(line)
        end
      end

      def persist(res)
        File.open(output_file_location, "a") do |f|
          f.puts res.to_json
        end
      end

      private

      def mark_acquisition_directory_as_finished_processing
        File.rename(acquisition_directory_processing, acquisition_directory_final)
      end
    end
  end
end
