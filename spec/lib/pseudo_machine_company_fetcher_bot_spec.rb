# frozen_string_literal: true

require_relative "../spec_helper"
require "openc_bot"
require "openc_bot/pseudo_machine_company_fetcher_bot"

Mail.defaults do
  delivery_method :test # no, don't send emails when testing
end

module TestPseudoMachineCompaniesFetcher
  extend OpencBot::PseudoMachineCompanyFetcherBot
end

module TestOutputStreamFinalizeBot
  module Fetcher
    def self.run
      { fetched: 1 }
    end
  end

  module Parser
    def self.run
      { parsed: 1 }
    end

    def self.finalize_output_stream!; end
  end

  module Transformer
    def self.run
      { transformed: 1 }
    end

    def self.finalize_output_stream!; end
  end
end

module OpencBot
  describe PseudoMachineCompanyFetcherBot do
    context "when a module extends PseudoMachineCompanyFetcherBot" do
      it "includes CompanyFetcherBot methods" do
        expect(TestPseudoMachineCompaniesFetcher).to respond_to(:inferred_jurisdiction_code)
      end

      it "finalizes parser and transformer output after those stages succeed" do
        tmp = Dir.mktmpdir("parakeet_finalize_")

        allow(TestPseudoMachineCompaniesFetcher).to receive(:callable_from_file_name).and_return(TestOutputStreamFinalizeBot)
        allow(TestPseudoMachineCompaniesFetcher).to receive(:send_error_report)
        allow(TestPseudoMachineCompaniesFetcher).to receive(:mark_acquisition_directory_as_finished_processing)
        allow(TestPseudoMachineCompaniesFetcher).to receive(:acquisition_directory_final).and_return(tmp)

        expect(TestOutputStreamFinalizeBot::Parser).to receive(:finalize_output_stream!).and_call_original
        expect(TestOutputStreamFinalizeBot::Transformer).to receive(:finalize_output_stream!).and_call_original
        expect(TestOutputStreamFinalizeBot::Fetcher).not_to receive(:finalize_output_stream!)

        begin
          ENV["ACQUISITION_DIRECTORY"] = tmp
          TestPseudoMachineCompaniesFetcher.instance_variable_set(:@processing_states, nil)
          TestPseudoMachineCompaniesFetcher.instance_variable_set(:@acquisition_directory, nil)
          TestPseudoMachineCompaniesFetcher.update_data
        ensure
          ENV.delete("ACQUISITION_DIRECTORY")
          TestPseudoMachineCompaniesFetcher.instance_variable_set(:@processing_states, nil)
          TestPseudoMachineCompaniesFetcher.instance_variable_set(:@acquisition_directory, nil)
          FileUtils.remove_entry(tmp)
        end
      end
    end
  end
end
