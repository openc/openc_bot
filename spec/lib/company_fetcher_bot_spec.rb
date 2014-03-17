# encoding: UTF-8
require_relative '../spec_helper'
require 'openc_bot'
require 'openc_bot/company_fetcher_bot'

module TestCompanyFetcherBot
  extend OpencBot::CompanyFetcherBot
end


describe "A module that extends CompanyFetcherBot" do

  before do
    @dummy_connection = double('database_connection')
    TestCompanyFetcherBot.stub(:sqlite_magic_connection).and_return(@dummy_connection)
  end

  it "should include OpencBot methods" do
    TestCompanyFetcherBot.should respond_to(:save_run_report)
  end

  it "should include IncrementalHelper methods" do
    TestCompanyFetcherBot.should respond_to(:incremental_search)
  end

  it "should set PRIMARY_KEY_NAME to :company_number" do
    TestCompanyFetcherBot.primary_key_name.should == :company_number
  end

  describe "#validate_datum" do
    before do
      @valid_params = {:name => 'Foo Inc', :company_number => '12345', :jurisdiction_code => 'ie'}
    end

    it "should check json version of datum against company schema" do
      JSON::Validator.should_receive(:fully_validate).with(File.expand_path("../../../schemas/company-schema.json", __FILE__), @valid_params.to_json, anything)
      TestCompanyFetcherBot.validate_datum(@valid_params)
    end

    context "and datum is valid" do
      it "should return empty array" do
        TestCompanyFetcherBot.validate_datum(@valid_params).should == []
      end
    end

    context "and datum is not valid" do
      it "should return errors" do
        result = TestCompanyFetcherBot.validate_datum({:name => 'Foo Inc', :jurisdiction_code => 'ie'})
        result.should be_kind_of Array
        result.size.should == 1
        result.first[:failed_attribute].should == "Required"
        result.first[:message].should match 'company_number'
      end
    end
  end

end