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
        dir = ENV.fetch("ACQUISITION_BASE_DIRECTORY", "data/acquisition")
        Dir.mkdir(dir) unless Dir.exist?(dir)
        dir
      end

      def acquisition_id
        @acquisition_id ||= ENV["FORCE_NEW_ACQUISITION"].blank? ? ENV["ACQUISITION_ID"] || in_progress_acquisition_id || Time.now.to_i.to_s : Time.now.to_i.to_s
      end

      # gets the most recent in progress acquisition id, based on in processing
      # directories
      def in_progress_acquisition_id
        return @acquisition_id unless @acquisition_id.blank?

        in_progress_acquisitions = Dir.glob("#{acquisition_base_directory}/*_processing").sort
        in_progress_acquisitions.blank? ? nil : in_progress_acquisitions.last.split("/").last.sub("_processing", "")
      end

      def input_file_location
        File.join(acquisition_directory_processing, "#{input_stream}.jsonl")
      end

      def output_file_location
        File.join(acquisition_directory_processing, "#{output_stream}.jsonl")
      end

      def acquisition_directory_processing
        processing_directory = ENV["ACQUISITION_DIRECTORY"] || File.join(acquisition_base_directory, "#{acquisition_id}_processing")
        unless Dir.exist?(processing_directory)
          if ENV["ACQUISITION_ID"]
            mark_finished_acquisition_directory_as_processing(processing_directory)
          else
            FileUtils.mkdir(processing_directory)
          end
        end
        @acquisition_directory ||= processing_directory
        processing_directory
      end

      def acquisition_directory_final
        @acquisition_directory = File.join(acquisition_base_directory, in_progress_acquisition_id)
      end

      def records_processed
        `wc -l "#{output_file_location}"`.strip.split[0].to_i
      end

      def input_data
        File.foreach(input_file_location) do |line|
          yield JSON.parse(line)
        end
      rescue Errno::ENOENT
        warn "No such file: #{input_file_location} present"
        []
      end

      def persist(res)
        File.open(output_file_location, "a") do |f|
          f.puts res.to_json
        end
      end

      def acquisition_directory
        @acquisition_directory || acquisition_directory_processing
      end

      private

      def mark_acquisition_directory_as_finished_processing
        File.rename(acquisition_directory_processing, acquisition_directory_final)
      end

      def mark_finished_acquisition_directory_as_processing(processing_directory)
        File.rename(acquisition_directory_final, processing_directory)
      end
    end
  end
end
