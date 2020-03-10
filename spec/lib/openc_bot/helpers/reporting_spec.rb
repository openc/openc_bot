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

  describe "#track_company_processed" do
    before do
      allow(ModuleThatIncludesReporting).to receive(:report_progress_to_analysis_app)
    end

    context "when last_reported_progress has not been initialised (first iteration)" do
      before do
        ModuleThatIncludesReporting.remove_instance_variable(:@last_reported_progress) if ModuleThatIncludesReporting.instance_variable_defined?(:@last_reported_progress)
        ModuleThatIncludesReporting.remove_instance_variable(:@processed_count) if ModuleThatIncludesReporting.instance_variable_defined?(:@processed_count)

        ModuleThatIncludesReporting.track_company_processed
      end

      it "starts the process count" do
        expect(ModuleThatIncludesReporting.instance_variable_get(:@processed_count)).to eq(1)
      end

      it "does a report on this first iteration" do
        expect(ModuleThatIncludesReporting).to have_received(:report_progress_to_analysis_app)
      end

      it "initialises the last_reported_progress time" do
        expect(ModuleThatIncludesReporting.instance_variable_get(:@last_reported_progress)).to be_within(1.minute).of(Time.now)
      end
    end

    context "when last_reported_progress was over 5 minute ago" do
      before do
        ModuleThatIncludesReporting.instance_variable_set(:@last_reported_progress, 10.minutes.ago)
        ModuleThatIncludesReporting.instance_variable_set(:@processed_count, 123)

        ModuleThatIncludesReporting.track_company_processed
      end

      it "increments the existing process count" do
        expect(ModuleThatIncludesReporting.instance_variable_get(:@processed_count)).to eq(124)
      end

      it "does a report" do
        expect(ModuleThatIncludesReporting).to have_received(:report_progress_to_analysis_app)
      end

      it "resets the last_reported_progress time" do
        expect(ModuleThatIncludesReporting.instance_variable_get(:@last_reported_progress)).to be_within(1.minute).of(Time.now)
      end
    end

    context "when last_reported_progress was quite recent" do
      before do
        ModuleThatIncludesReporting.instance_variable_set(:@last_reported_progress, 10.seconds.ago)
        ModuleThatIncludesReporting.instance_variable_set(:@processed_count, 123)

        ModuleThatIncludesReporting.track_company_processed
      end

      it "increments the existing process count" do
        expect(ModuleThatIncludesReporting.instance_variable_get(:@processed_count)).to eq(124)
      end

      it "does not send a report" do
        expect(ModuleThatIncludesReporting).not_to have_received(:report_progress_to_analysis_app)
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
