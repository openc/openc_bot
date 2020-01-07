require_relative "../spec_helper"
require "openc_bot"
require "openc_bot/company_fetcher_bot"

Mail.defaults do
  delivery_method :test # no, don't send emails when testing
end

module TestCompaniesFetcher
  extend OpencBot::CompanyFetcherBot
end

module UsXxCompaniesFetcher
  extend OpencBot::CompanyFetcherBot
end

describe "A module that extends CompanyFetcherBot" do
  before do
    @dummy_connection = double("database_connection", save_data: nil)
    allow(TestCompaniesFetcher).to receive(:sqlite_magic_connection).and_return(@dummy_connection)
    allow(TestCompaniesFetcher).to receive(:_http_post)
  end

  it "includes OpencBot methods" do
    expect(TestCompaniesFetcher).to respond_to(:save_run_report)
  end

  it "includes IncrementalHelper methods" do
    expect(TestCompaniesFetcher).to respond_to(:incremental_search)
  end

  it "includes AlphaHelper methods" do
    expect(TestCompaniesFetcher).to respond_to(:letters_and_numbers)
  end

  it "sets primary_key_name to :company_number" do
    expect(TestCompaniesFetcher.primary_key_name).to eq(:company_number)
  end

  describe "#fetch_datum for company_number" do
    before do
      allow(TestCompaniesFetcher).to receive(:fetch_registry_page)
    end

    it "#fetch_registry_pages for company_numbers" do
      expect(TestCompaniesFetcher).to receive(:fetch_registry_page).with("76543", {})
      TestCompaniesFetcher.fetch_datum("76543")
    end

    it "stores result of #fetch_registry_page in hash keyed to :company_page" do
      allow(TestCompaniesFetcher).to receive(:fetch_registry_page).and_return(:registry_page_html)
      expect(TestCompaniesFetcher.fetch_datum("76543")).to eq(company_page: :registry_page_html)
    end

    context "and options passed in" do
      it "passes on to fetch_registry_page" do
        expect(TestCompaniesFetcher).to receive(:fetch_registry_page).with("76543", foo: "bar")
        TestCompaniesFetcher.fetch_datum("76543", foo: "bar")
      end
    end
  end

  describe "#schema_name" do
    context "and no SCHEMA_NAME constant" do
      it "returns 'company-schema'" do
        expect(TestCompaniesFetcher.schema_name).to eq("company-schema")
      end
    end

    context "and SCHEMA_NAME constant set" do
      it "returns SCHEMA_NAME" do
        stub_const("TestCompaniesFetcher::SCHEMA_NAME", "foo-schema")
        expect(TestCompaniesFetcher.schema_name).to eq("foo-schema")
      end
    end
  end

  describe "#inferred_jurisdiction_code" do
    it "returns jurisdiction_code inferred from class_name" do
      expect(UsXxCompaniesFetcher.inferred_jurisdiction_code).to eq("us_xx")
    end

    it "returns nil if jurisdiction_code not correct format" do
      expect(TestCompaniesFetcher.inferred_jurisdiction_code).to be_nil
    end
  end

  describe "#save_entity" do
    before do
      allow(TestCompaniesFetcher).to receive(:inferred_jurisdiction_code).and_return("ab_cd")
    end

    it "save_entities with inferred_jurisdiction_code" do
      expect(TestCompaniesFetcher).to receive(:prepare_and_save_data).with(name: "Foo Corp", company_number: "12345", jurisdiction_code: "ab_cd", retrieved_at: "2018-01-01")
      TestCompaniesFetcher.save_entity(name: "Foo Corp", company_number: "12345", retrieved_at: "2018-01-01")
    end

    it "save_entities with given jurisdiction_code" do
      expect(TestCompaniesFetcher).to receive(:prepare_and_save_data).with(name: "Foo Corp", company_number: "12345", jurisdiction_code: "xx", retrieved_at: "2018-01-01")
      TestCompaniesFetcher.save_entity(name: "Foo Corp", company_number: "12345", jurisdiction_code: "xx", retrieved_at: "2018-01-01")
    end
  end

  describe "#save_entity!" do
    before do
      allow(TestCompaniesFetcher).to receive(:inferred_jurisdiction_code).and_return("ab_cd")
    end

    it "save_entities with inferred_jurisdiction_code" do
      expect(TestCompaniesFetcher).to receive(:prepare_and_save_data).with(name: "Foo Corp", company_number: "12345", jurisdiction_code: "ab_cd", retrieved_at: "2018-01-01")
      TestCompaniesFetcher.save_entity!(name: "Foo Corp", company_number: "12345", retrieved_at: "2018-01-01")
    end

    it "save_entities with given jurisdiction_code" do
      expect(TestCompaniesFetcher).to receive(:prepare_and_save_data).with(name: "Foo Corp", company_number: "12345", jurisdiction_code: "xx", retrieved_at: "2018-01-01")
      TestCompaniesFetcher.save_entity!(name: "Foo Corp", company_number: "12345", jurisdiction_code: "xx", retrieved_at: "2018-01-01")
    end

    context "and entity_data is not valid" do
      before do
        allow(TestCompaniesFetcher).to receive(:validate_datum).and_return([{ message: "Not valid" }])
      end

      it "does not prepare and save data" do
        expect(TestCompaniesFetcher).not_to receive(:prepare_and_save_data)
        -> { ModuleThatIncludesRegisterMethods.save_entity!(name: "Foo Corp", company_number: "12345") }
      end

      it "raises exception" do
        expect { TestCompaniesFetcher.save_entity!(name: "Foo Corp", company_number: "12345") }.to raise_error(OpencBot::RecordInvalid)
      end
    end
  end

  describe "#update_data" do
    before do
      allow(TestCompaniesFetcher).to receive(:fetch_data).and_return(added: 3)
      allow(TestCompaniesFetcher).to receive(:update_stale).and_return(updated: 42)
      # this can be any file that we can stat
      allow(TestCompaniesFetcher).to receive(:db_location)
        .and_return(File.join(File.dirname(__FILE__), "company_fetcher_bot_spec.rb"))
    end

    it "fetch_datas" do
      expect(TestCompaniesFetcher).to receive(:update_stale)
      TestCompaniesFetcher.update_data
    end

    it "update_stales" do
      expect(TestCompaniesFetcher).to receive(:fetch_data)
      TestCompaniesFetcher.update_data
    end

    it "returns the results of fetching/updating stale" do
      result = TestCompaniesFetcher.update_data
      expect(result).to eq(added: 3, updated: 42)
    end

    context "and Exception raised" do
      it "sends error report with options passed in to update_data" do
        exception = RuntimeError.new("something went wrong")
        allow(TestCompaniesFetcher).to receive(:fetch_data).and_raise(exception)
        expect(TestCompaniesFetcher).to receive(:send_error_report).with(exception, foo: "bar")
        expect { TestCompaniesFetcher.update_data(foo: "bar") }.to raise_error(exception)
      end
    end
  end

  describe "#run" do
    before do
      allow(TestCompaniesFetcher).to receive(:db_location)
        .and_return(File.join(File.dirname(__FILE__), "company_fetcher_bot_spec.rb"))
      allow(TestCompaniesFetcher).to receive(:update_data).and_return(foo: "bar")
      allow(TestCompaniesFetcher).to receive(:current_git_commit).and_return("abc12345")
      Mail::TestMailer.deliveries.clear
    end

    it "update_datas" do
      expect(TestCompaniesFetcher).to receive(:update_data)
      TestCompaniesFetcher.run
    end

    it "sends report_run_results with results of update_data" do
      expect(TestCompaniesFetcher).to receive(:report_run_results).with(hash_including(foo: "bar"))
      TestCompaniesFetcher.run
    end

    it "sends report_run_results with start and end times of bot" do
      expect(TestCompaniesFetcher).to receive(:report_run_results).with(hash_including(:started_at, :ended_at))
      TestCompaniesFetcher.run
    end

    it "posts a run report to the analysis app" do
      expected_params = {
        run: hash_including(foo: "bar", bot_id: "test_companies_fetcher", bot_type: "external", status_code: "1", git_commit: "abc12345"),
      }
      expect(TestCompaniesFetcher).to receive(:_http_post).with("#{OpencBot::CompanyFetcherBot::ANALYSIS_HOST}/runs", expected_params)
      TestCompaniesFetcher.run
    end
  end

  describe "#report_run_progress" do
    it "posts a progress report to the analysis app fetcher_progress_log endpoint" do
      expected_params = { data: { bot_id: "test_companies_fetcher", companies_processed: 3, companies_added: 2, companies_updated: 1 }.to_json }
      expect(TestCompaniesFetcher).to receive(:_http_post).with("#{OpencBot::CompanyFetcherBot::ANALYSIS_HOST}/fetcher_progress_log", expected_params)
      TestCompaniesFetcher.report_run_progress(companies_processed: 3, companies_added: 2, companies_updated: 1)
    end

    it "posts null values in the json payload for absent stats" do
      expected_params = { data: { bot_id: "test_companies_fetcher", companies_processed: 3, companies_added: nil, companies_updated: nil }.to_json }
      expect(TestCompaniesFetcher).to receive(:_http_post).with("#{OpencBot::CompanyFetcherBot::ANALYSIS_HOST}/fetcher_progress_log", expected_params)
      TestCompaniesFetcher.report_run_progress(companies_processed: 3)
    end
  end

  describe "#report_run_to_oc" do
    it "supports this deprecated method (called by many external bots) but actually sends a report to the analysis app" do
      expect(TestCompaniesFetcher.method(:report_run_to_oc)).to eq(TestCompaniesFetcher.method(:report_run_to_analysis_app))
    end
  end
end
