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
  describe "#report_run_progress" do
    it "posts a progress report to the analysis app fetcher_progress_log endpoint" do
      expected_params = { data: { bot_id: "module_that_includes_reporting", companies_processed: 3, companies_added: 2, companies_updated: 1 }.to_json }
      expect(ModuleThatIncludesReporting).to receive(:_analysis_http_post).with("#{OpencBot::Helpers::Reporting::ANALYSIS_HOST}/fetcher_progress_log", expected_params)
      ModuleThatIncludesReporting.report_run_progress(companies_processed: 3, companies_added: 2, companies_updated: 1)
    end

    it "posts null values in the json payload for absent stats" do
      expected_params = { data: { bot_id: "module_that_includes_reporting", companies_processed: 3, companies_added: nil, companies_updated: nil }.to_json }
      expect(ModuleThatIncludesReporting).to receive(:_analysis_http_post).with("#{OpencBot::Helpers::Reporting::ANALYSIS_HOST}/fetcher_progress_log", expected_params)
      ModuleThatIncludesReporting.report_run_progress(companies_processed: 3)
    end
  end

  describe "#report_run_to_oc" do
    it "supports this deprecated method (called by many external bots) but actually sends a report to the analysis app" do
      expect(ModuleThatIncludesReporting.method(:report_run_to_oc)).to eq(ModuleThatIncludesReporting.method(:report_run_to_analysis_app))
    end
  end
end
