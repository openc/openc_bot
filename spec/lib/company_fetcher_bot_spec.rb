# encoding: UTF-8
require_relative '../spec_helper'
require 'openc_bot'
require 'openc_bot/company_fetcher_bot'

module TestCompanyFetcherBot
  extend OpencBot::CompanyFetcherBot
end

describe "A module that extends CompanyFetcherBot" do

  before do
    @dummy_connection = double('database_connection', :save_data => nil)
    TestCompanyFetcherBot.stub(:sqlite_magic_connection).and_return(@dummy_connection)
  end

  it "should include OpencBot methods" do
    TestCompanyFetcherBot.should respond_to(:save_run_report)
  end

  it "should include IncrementalHelper methods" do
    TestCompanyFetcherBot.should respond_to(:incremental_search)
  end

  it "should include AlphaHelper methods" do
    TestCompanyFetcherBot.should respond_to(:letters_and_numbers)
  end

  it "should set primary_key_name to :company_number" do
    TestCompanyFetcherBot.primary_key_name.should == :company_number
  end

  describe "#fetch_datum for company_number" do
    before do
      TestCompanyFetcherBot.stub(:fetch_registry_page)
    end

    it "should #fetch_registry_page for company_numbers" do
      TestCompanyFetcherBot.should_receive(:fetch_registry_page).with('76543')
      TestCompanyFetcherBot.fetch_datum('76543')
    end

    it "should stored result of #fetch_registry_page in hash keyed to :company_page" do
      TestCompanyFetcherBot.stub(:fetch_registry_page).and_return(:registry_page_html)
      TestCompanyFetcherBot.fetch_datum('76543').should == {:company_page => :registry_page_html}
    end
  end

end