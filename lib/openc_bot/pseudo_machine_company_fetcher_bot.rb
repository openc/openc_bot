# frozen_string_literal: true

require "openc_bot"
require "openc_bot/company_fetcher_bot"
require "openc_bot/helpers/persistence_handler"

module OpencBot
  # Psuedo machine fetcher bot top level class to orchestrate activities
  module PseudoMachineCompanyFetcherBot
    include OpencBot::CompanyFetcherBot
    include OpencBot::Helpers::PersistenceHandler

    def bot_name
      @bot_name ||= Dir.pwd.split("/").last
    end

    def callable_from_file_name(underscore_file_name)
      bot_klass = klass_from_file_name(underscore_file_name)
      if bot_klass.respond_to?(:new)
        bot_klass.new
      else
        bot_klass
      end
    end

    def klass_from_file_name(underscore_file_name)
      camelcase_version = underscore_file_name.split("_").map(&:capitalize).join
      Object.const_get(camelcase_version)
    end

    def db_name
      "#{bot_name.gsub('_', '').downcase}.db"
    end

    def statsd_namespace
      puts "Getting statsD namespace"
      @statsd_namespace ||= begin
        bot_env = ENV.fetch("FETCHER_BOT_ENV", "development").to_sym
        StatsD.mode = bot_env
        StatsD.server = "sys1:8125"
        StatsD.logger = Logger.new("/dev/null") if bot_env != :production

        puts "bot_env is #{bot_env}"

        if respond_to?(:output_stream)
          puts "Responds to output_stream"
          if respond_to?(:inferred_jurisdiction_code) && inferred_jurisdiction_code
            puts "Responds to inferred_jur_code"
            "pseudo_machine_bot.#{bot_env}.#{inferred_jurisdiction_code}.#{output_stream}"
          elsif is_a?(Module)
            puts "is a Module"
            "pseudo_machine_bot.#{bot_env}.#{name.downcase}.#{output_stream}"
          else
            puts "in the else clause of statsd namespace"
            "pseudo_machine_bot.#{bot_env}.#{self.class.name.downcase}.#{output_stream}"
          end
          .sub("companiesfetcher", "")
        end
      end
    end

    def processing_states
      return @processing_states unless @processing_states.nil?

      state_file = "#{acquisition_directory}/processing_states.json"
      @processing_states = if File.exist?(state_file)
                             JSON.parse(IO.read(state_file))
                           else
                             []
                           end
    end

    # Outline bot run logic.
    def update_data(options = {})
      res = {}
      bot_namespace = callable_from_file_name(bot_name)
      unless processing_states.include?("fetcher")
        res.merge!(bot_namespace::Fetcher.run)
        processing_states << "fetcher"
      end
      unless processing_states.include?("parser")
        res.merge!(bot_namespace::Parser.run)
        processing_states << "parser"
      end
      unless @processing_states.include?("transformer")
        res.merge!(bot_namespace::Transformer.run)
        processing_states << "transformer"
      end
      if res[:no_transformed_data]
        # we don't need to keep empty acquisitions
        remove_current_processing_acquisition_directory
      else
        res[:data_directory] = acquisition_directory_final
        # rename directory so it will be seen by importer
        mark_acquisition_directory_as_finished_processing
      end
      raise "\n#{JSON.pretty_generate(res)}" if res.key?(:fetch_data_error) || res.key?(:update_stale_error)

      res
    rescue StandardError => e
      send_error_report(e, options)
      raise e
    ensure
      IO.write("#{acquisition_directory}/processing_states.json", processing_states.to_json) if Dir.exist?(acquisition_directory)
    end
  end
end
