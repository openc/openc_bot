# encoding: UTF-8
require_relative '../spec_helper'
require 'openc_bot'
require 'openc_bot/company_fetcher_bot'

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
    @dummy_connection = double('database_connection', :save_data => nil)
    TestCompaniesFetcher.stub(:sqlite_magic_connection).and_return(@dummy_connection)
    TestCompaniesFetcher.stub(:_http_post)
  end

  it "should include OpencBot methods" do
    TestCompaniesFetcher.should respond_to(:save_run_report)
  end

  it "should include IncrementalHelper methods" do
    TestCompaniesFetcher.should respond_to(:incremental_search)
  end

  it "should include AlphaHelper methods" do
    TestCompaniesFetcher.should respond_to(:letters_and_numbers)
  end

  it "should set primary_key_name to :company_number" do
    TestCompaniesFetcher.primary_key_name.should == :company_number
  end

  describe "#fetch_datum for company_number" do
    before do
      TestCompaniesFetcher.stub(:fetch_registry_page)
    end

    it "should #fetch_registry_page for company_numbers" do
      TestCompaniesFetcher.should_receive(:fetch_registry_page).with('76543',{})
      TestCompaniesFetcher.fetch_datum('76543')
    end

    it "should stored result of #fetch_registry_page in hash keyed to :company_page" do
      TestCompaniesFetcher.stub(:fetch_registry_page).and_return(:registry_page_html)
      TestCompaniesFetcher.fetch_datum('76543').should == {:company_page => :registry_page_html}
    end

    context 'and options passed in' do
      it 'should pass on to fetch_registry_page' do
        TestCompaniesFetcher.should_receive(:fetch_registry_page).with('76543', :foo => 'bar')
        TestCompaniesFetcher.fetch_datum('76543', :foo => 'bar')
      end
    end
  end

  describe "#schema_name" do
    context 'and no SCHEMA_NAME constant' do
      it "should return 'company-schema'" do
        TestCompaniesFetcher.schema_name.should == 'company-schema'
      end
    end

    context 'and SCHEMA_NAME constant set' do
      it "should return SCHEMA_NAME" do
        stub_const("TestCompaniesFetcher::SCHEMA_NAME", 'foo-schema')
        TestCompaniesFetcher.schema_name.should == 'foo-schema'
      end
    end
  end

  describe "#inferred_jurisdiction_code" do
    it "should return jurisdiction_code inferred from class_name" do
      UsXxCompaniesFetcher.inferred_jurisdiction_code.should == 'us_xx'
    end

    it "should return nil if jurisdiction_code not correct format" do
      TestCompaniesFetcher.inferred_jurisdiction_code.should be_nil
    end
  end

  describe "#save_entity" do
    before do
      TestCompaniesFetcher.stub(:inferred_jurisdiction_code).and_return('ab_cd')
    end

    it "should save_entity with inferred_jurisdiction_code" do
      TestCompaniesFetcher.should_receive(:prepare_and_save_data).with(:name => 'Foo Corp', :company_number => '12345', :jurisdiction_code => 'ab_cd')
      TestCompaniesFetcher.save_entity(:name => 'Foo Corp', :company_number => '12345')
    end

    it "should save_entity with given jurisdiction_code" do
      TestCompaniesFetcher.should_receive(:prepare_and_save_data).with(:name => 'Foo Corp', :company_number => '12345', :jurisdiction_code => 'xx')
      TestCompaniesFetcher.save_entity(:name => 'Foo Corp', :company_number => '12345', :jurisdiction_code => 'xx')
    end
  end

  describe "#save_entity!" do
    before do
      TestCompaniesFetcher.stub(:inferred_jurisdiction_code).and_return('ab_cd')
    end

    it "should save_entity with inferred_jurisdiction_code" do
      TestCompaniesFetcher.should_receive(:prepare_and_save_data).with(:name => 'Foo Corp', :company_number => '12345', :jurisdiction_code => 'ab_cd')
      TestCompaniesFetcher.save_entity!(:name => 'Foo Corp', :company_number => '12345')
    end

    it "should save_entity with given jurisdiction_code" do
      TestCompaniesFetcher.should_receive(:prepare_and_save_data).with(:name => 'Foo Corp', :company_number => '12345', :jurisdiction_code => 'xx')
      TestCompaniesFetcher.save_entity!(:name => 'Foo Corp', :company_number => '12345', :jurisdiction_code => 'xx')
    end

    context "and entity_data is not valid" do
      before do
        TestCompaniesFetcher.stub(:validate_datum).and_return([{:message=>'Not valid'}])
      end

      it "should not prepare and save data" do
        TestCompaniesFetcher.should_not_receive(:prepare_and_save_data)
        lambda {ModuleThatIncludesRegisterMethods.save_entity!(:name => 'Foo Corp', :company_number => '12345')}
      end

      it "should raise exception" do
        lambda {TestCompaniesFetcher.save_entity!(:name => 'Foo Corp', :company_number => '12345')}.should raise_error(OpencBot::RecordInvalid)
      end
    end
  end

  describe '#update_data' do
    before do
      TestCompaniesFetcher.stub(:fetch_data).and_return({:added => 3})
      TestCompaniesFetcher.stub(:update_stale).and_return({:updated => 42})
     #this can be any file that we can stat
      TestCompaniesFetcher.stub(:db_location).
        and_return(File.join(File.dirname(__FILE__),"company_fetcher_bot_spec.rb"))
    end

    it 'should fetch_data' do
      TestCompaniesFetcher.should_receive(:update_stale)
      TestCompaniesFetcher.update_data
    end

    it 'should update_stale' do
      TestCompaniesFetcher.should_receive(:fetch_data)
      TestCompaniesFetcher.update_data
    end

    it 'should return the results of fetching/updating stale' do
      result = TestCompaniesFetcher.update_data
      result.should == {:added => 3, :updated => 42}
    end

    context 'and Exception raised' do
      it 'should send error report with options passed in to update_data' do
        exception = RuntimeError.new('something went wrong')
        TestCompaniesFetcher.stub(:fetch_data).and_raise(exception)
        TestCompaniesFetcher.should_receive(:send_error_report).with(exception, :foo => 'bar')
        result = TestCompaniesFetcher.update_data(:foo => 'bar')
      end
    end
  end

  describe '#run' do
    before do
      TestCompaniesFetcher.stub(:db_location).
        and_return(File.join(File.dirname(__FILE__),"company_fetcher_bot_spec.rb"))
      TestCompaniesFetcher.stub(:update_data).and_return({:foo => 'bar'})
      TestCompaniesFetcher.stub(:current_git_commit).and_return('abc12345')
      Mail::TestMailer.deliveries.clear
    end

    it 'should update_data' do
      TestCompaniesFetcher.should_receive(:update_data)
      TestCompaniesFetcher.run
    end

    it 'should send report_run_results with results of update_data' do
      TestCompaniesFetcher.should_receive(:report_run_results).with(hash_including({:foo => 'bar'}))
      TestCompaniesFetcher.run
    end

    it 'should send report_run_results with start and end times of bot' do
      TestCompaniesFetcher.should_receive(:report_run_results).with(hash_including(:started_at, :ended_at))
      TestCompaniesFetcher.run
    end

    it 'should post report to OpenCorporates' do
      expected_params = {:run => hash_including({:foo=>"bar", :bot_id=>"test_companies_fetcher", :bot_type=>"external", :status_code=>"1", :git_commit => 'abc12345'})}
      TestCompaniesFetcher.should_receive(:_http_post).with(OpencBot::CompanyFetcherBot::OC_RUN_REPORT_URL, expected_params)
      TestCompaniesFetcher.run
    end

  end
end