# frozen_string_literal: true

module OpencBot
  module Helpers
    # Persistence handler for bot activities
    module PersistenceHandler
      DEFAULT_CHECKPOINT_EVERY = 1000
      JSONL_CHECKPOINT_STAGES = %w[parser transformer].freeze

      def input_stream
        # override in segment bots
      end

      def output_stream
        name.to_s[/[A-Z][a-z]+$/].downcase
      end

      def acquisition_base_directory
        dir = ENV.fetch("ACQUISITION_BASE_DIRECTORY", File.join(data_dir, "acquisitions"))
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

      def jsonl_partial_path
        "#{output_file_location}.partial"
      end

      def jsonl_checkpoint_path
        "#{output_file_location}.checkpoint.json"
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
        path = if File.exist?(output_file_location)
                 output_file_location
               elsif File.exist?(jsonl_partial_path)
                 jsonl_partial_path
               end
        return 0 unless path

        `wc -l "#{path}"`.strip.split[0].to_i
      end

      def jsonl_checkpoint_enabled?
        ENV["OPENC_BOT_JSONL_CHECKPOINT"] != "0" && JSONL_CHECKPOINT_STAGES.include?(output_stream)
      end

      def jsonl_records_written
        return 0 unless jsonl_checkpoint_enabled?

        jsonl_checkpoint_state[:count]
      end

      def prepare_output_for_stage!
        return unless jsonl_checkpoint_enabled?

        close_jsonl_partial_io
        checkpoint = load_jsonl_checkpoint
        if checkpoint
          @jsonl_checkpoint_state = checkpoint
          open_jsonl_partial_io(resume: true)
        else
          discard_incomplete_jsonl_output
          @jsonl_checkpoint_state = default_jsonl_checkpoint
          @jsonl_partial_io = nil
        end
        @jsonl_output_prepared = true
      end

      def finalize_output_stream!
        return unless jsonl_checkpoint_enabled?

        if @jsonl_partial_io
          @jsonl_partial_io.flush
          @jsonl_partial_io.fsync
          close_jsonl_partial_io
        end

        File.rename(jsonl_partial_path, output_file_location) if File.exist?(jsonl_partial_path)
        FileUtils.rm_f(jsonl_checkpoint_path)
        FileUtils.rm_f("#{jsonl_checkpoint_path}.tmp")
        @jsonl_output_prepared = false
        @jsonl_checkpoint_state = nil
      end

      def input_data(&block)
        return legacy_input_data(&block) unless jsonl_checkpoint_enabled?

        prepare_output_for_stage! unless @jsonl_output_prepared

        File.open(input_file_location, "rb") do |input|
          skip_until = jsonl_checkpoint_state[:input_lines]
          if jsonl_checkpoint_state[:input_bytes].positive?
            input.seek(jsonl_checkpoint_state[:input_bytes])
            line_number = skip_until
          else
            line_number = 0
          end

          input.each_line do |line|
            line_number += 1
            next if line_number <= skip_until

            yield JSON.parse(line)
            jsonl_checkpoint_state[:input_lines] = line_number
            jsonl_checkpoint_state[:input_bytes] = input.pos
            maybe_write_jsonl_checkpoint
          end
        end
      rescue Errno::ENOENT => e
        warn "Error raised while processing the file: #{input_file_location}"
        warn "Requested file not found: #{e.message}"
        []
      end

      def persist(res)
        if jsonl_checkpoint_enabled?
          prepare_output_for_stage! unless @jsonl_output_prepared
          open_jsonl_partial_io unless @jsonl_partial_io
          @jsonl_partial_io.puts res.to_json
          jsonl_checkpoint_state[:count] += 1
          jsonl_checkpoint_state[:bytes] = @jsonl_partial_io.pos
        else
          File.open(output_file_location, "a") do |f|
            f.puts res.to_json
          end
        end
        track_company_processed
      end

      def acquisition_directory
        @acquisition_directory || acquisition_directory_processing
      end

      private

      def legacy_input_data
        File.foreach(input_file_location) do |line|
          yield JSON.parse(line)
        end
      rescue Errno::ENOENT => e
        warn "Error raised while processing the file: #{input_file_location}"
        warn "Requested file not found: #{e.message}"
        []
      end

      def jsonl_checkpoint_state
        @jsonl_checkpoint_state ||= default_jsonl_checkpoint
      end

      def default_jsonl_checkpoint
        { input_lines: 0, input_bytes: 0, bytes: 0, count: 0 }
      end

      def checkpoint_every
        [(ENV["CHECKPOINT_EVERY"] || DEFAULT_CHECKPOINT_EVERY).to_i, 1].max
      end

      def load_jsonl_checkpoint
        return unless File.exist?(jsonl_checkpoint_path) && File.exist?(jsonl_partial_path)

        data = JSON.parse(File.read(jsonl_checkpoint_path))
        return unless data.key?("input_lines") && data.key?("input_bytes") && data.key?("bytes") && data.key?("count")

        bytes = [data["bytes"].to_i, File.size(jsonl_partial_path)].min
        {
          input_lines: data["input_lines"].to_i,
          input_bytes: data["input_bytes"].to_i,
          bytes: bytes,
          count: data["count"].to_i
        }
      rescue JSON::ParserError
        nil
      end

      def discard_incomplete_jsonl_output
        close_jsonl_partial_io
        FileUtils.rm_f(output_file_location)
        FileUtils.rm_f(jsonl_partial_path)
        FileUtils.rm_f(jsonl_checkpoint_path)
        FileUtils.rm_f("#{jsonl_checkpoint_path}.tmp")
      end

      def open_jsonl_partial_io(resume: false)
        return @jsonl_partial_io if @jsonl_partial_io

        @jsonl_partial_io = File.open(jsonl_partial_path, File::WRONLY | File::CREAT)
        if resume
          @jsonl_partial_io.seek(jsonl_checkpoint_state[:bytes])
          @jsonl_partial_io.truncate(jsonl_checkpoint_state[:bytes])
        end
        @jsonl_partial_io
      end

      def close_jsonl_partial_io
        @jsonl_partial_io&.close
      rescue IOError
        nil
      ensure
        @jsonl_partial_io = nil
      end

      def maybe_write_jsonl_checkpoint
        return unless jsonl_checkpoint_state[:input_lines] % checkpoint_every == 0

        write_jsonl_checkpoint
      end

      def write_jsonl_checkpoint
        if @jsonl_partial_io
          @jsonl_partial_io.flush
          @jsonl_partial_io.fsync
          jsonl_checkpoint_state[:bytes] = @jsonl_partial_io.pos
        end

        tmp = "#{jsonl_checkpoint_path}.tmp"
        File.write(tmp, {
          "input_lines" => jsonl_checkpoint_state[:input_lines],
          "input_bytes" => jsonl_checkpoint_state[:input_bytes],
          "bytes" => jsonl_checkpoint_state[:bytes],
          "count" => jsonl_checkpoint_state[:count]
        }.to_json)
        File.rename(tmp, jsonl_checkpoint_path)
      end

      def mark_acquisition_directory_as_finished_processing
        File.rename(acquisition_directory_processing, acquisition_directory_final)
      end

      def mark_finished_acquisition_directory_as_processing(processing_directory)
        File.rename(acquisition_directory_final, processing_directory)
      end

      def remove_current_processing_acquisition_directory
        FileUtils.rm_rf(acquisition_directory_processing)
      end
    end
  end
end
