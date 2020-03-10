require "spec_helper"
require "openc_bot"
require "openc_bot/company_fetcher_bot"
require "openc_bot/helpers/reporting"

module ModuleThatIncludesReporting
  extend OpencBot
  extend OpencBot::CompanyFetcherBot
  extend OpencBot::Helpers::Reporting
end

describe OpencBot::Helpers::Reporting do
  before do
    allow(ModuleThatIncludesReporting).to receive(:reporting_enabled?).and_return(true)
    allow(ModuleThatIncludesReporting).to receive(:_analysis_http_post)
    ModuleThatIncludesReporting.remove_instance_variable(:@processed_count) if ModuleThatIncludesReporting.instance_variable_defined?(:@processed_count)
  end

  describe "#send_error_report" do
    before do
      allow(ModuleThatIncludesReporting).to receive(:send_report)
      allow(ModuleThatIncludesReporting).to receive(:report_run_to_analysis_app)
    end

    let(:exception) { RuntimeError.new("something went wrong") }

    context "without parameters" do
      before do
        ModuleThatIncludesReporting.send_error_report(exception)
      end

      it "calls send_report with suitable subject and body" do
        expect(ModuleThatIncludesReporting).to have_received(:send_report)
          .with(
            body: "Error details: #<RuntimeError: something went wrong>.\nBacktrace:\n",
            subject: "Error running ModuleThatIncludesReporting: something went wrong",
          )
      end

      it "calls report_run_to_analysis_app with '0' status and body details" do
        expect(ModuleThatIncludesReporting).to have_received(:report_run_to_analysis_app)
          .with(
            status_code: "0",
            output: "Error details: #<RuntimeError: something went wrong>.\nBacktrace:\n",
            started_at: nil,
            ended_at: kind_of(String),
          )
      end
    end

    context "with subject_details option" do
      before do
        ModuleThatIncludesReporting.send_error_report(
          exception,
          subject_details: "Extra text for the email subject",
        )
      end

      it "uses the supplied text in the email subject" do
        expect(ModuleThatIncludesReporting).to have_received(:send_report)
          .with(
            body: "Error details: #<RuntimeError: something went wrong>.\nBacktrace:\n",
            subject: "Error running ModuleThatIncludesReporting: Extra text for the email subject",
          )
      end
    end
  end

  describe "#report_progress_to_analysis_app" do
    context "with increment_progress_counters having been called (progress to report)" do
      before do
        ModuleThatIncludesReporting.increment_progress_counters(companies_processed_delta: 3)
      end

      it "posts a progress report to the analysis app fetcher_progress_log endpoint" do
        expected_params = { data: { bot_id: "module_that_includes_reporting", companies_processed: 3, companies_added: nil, companies_updated: nil }.to_json }
        expect(ModuleThatIncludesReporting).to receive(:_analysis_http_post).with("#{OpencBot::Helpers::Reporting::ANALYSIS_HOST}/fetcher_progress_log", expected_params)
        ModuleThatIncludesReporting.report_progress_to_analysis_app
      end
    end

    context "without progress (counter not initialised)" do
      it "posts null values in the json payload for companies_processed (as well as the other absent stats)" do
        expected_params = { data: { bot_id: "module_that_includes_reporting", companies_processed: nil, companies_added: nil, companies_updated: nil }.to_json }
        expect(ModuleThatIncludesReporting).to receive(:_analysis_http_post).with("#{OpencBot::Helpers::Reporting::ANALYSIS_HOST}/fetcher_progress_log", expected_params)
        ModuleThatIncludesReporting.report_progress_to_analysis_app
      end
    end
  end

  describe "#increment_progress_counters" do
    it "increments the processed_count instance var by the specified delta" do
      ModuleThatIncludesReporting.increment_progress_counters(companies_processed_delta: 2)
      ModuleThatIncludesReporting.increment_progress_counters(companies_processed_delta: 2)
      expect(ModuleThatIncludesReporting.instance_variable_get(:@processed_count)).to eq 4
    end
  end

  describe "#report_run_to_oc" do
    it "supports this deprecated method (called by many external bots) but actually sends a report to the analysis app" do
      expect(ModuleThatIncludesReporting.method(:report_run_to_oc)).to eq(ModuleThatIncludesReporting.method(:report_run_to_analysis_app))
    end
  end
end
