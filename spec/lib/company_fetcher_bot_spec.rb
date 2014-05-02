# encoding: UTF-8
require_relative '../spec_helper'
require 'openc_bot'
require 'openc_bot/company_fetcher_bot'

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
      TestCompaniesFetcher.should_receive(:fetch_registry_page).with('76543')
      TestCompaniesFetcher.fetch_datum('76543')
    end

    it "should stored result of #fetch_registry_page in hash keyed to :company_page" do
      TestCompaniesFetcher.stub(:fetch_registry_page).and_return(:registry_page_html)
      TestCompaniesFetcher.fetch_datum('76543').should == {:company_page => :registry_page_html}
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
end