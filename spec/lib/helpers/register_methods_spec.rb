# encoding: UTF-8
require_relative '../../spec_helper'
require 'openc_bot'
require 'openc_bot/helpers/register_methods'

module ModuleThatIncludesRegisterMethods
  extend OpencBot
  extend OpencBot::Helpers::RegisterMethods
  PRIMARY_KEY_NAME = :custom_uid
end

module ModuleWithNoCustomPrimaryKey
  extend OpencBot
  extend OpencBot::Helpers::RegisterMethods
end

describe 'a module that includes RegisterMethods' do

  before do
    ModuleThatIncludesRegisterMethods.stub(:sqlite_magic_connection).
                                      and_return(test_database_connection)
  end

  after do
    remove_test_database
  end

  describe "#datum_exists?" do
    before do
      ModuleThatIncludesRegisterMethods.stub(:select).and_return([])

    end

    it "should select_data from database" do
      expected_sql_query = "ocdata.custom_uid FROM ocdata WHERE custom_uid = '?' LIMIT 1"
      ModuleThatIncludesRegisterMethods.should_receive(:select).with(expected_sql_query, '4567').and_return([])
      ModuleThatIncludesRegisterMethods.datum_exists?('4567')
    end

    it "should return true if result returned" do
      ModuleThatIncludesRegisterMethods.stub(:select).and_return([{'custom_uid' => '4567'}])

      ModuleThatIncludesRegisterMethods.datum_exists?('4567').should be_true
    end

    it "should return false if result returned" do
      ModuleThatIncludesRegisterMethods.datum_exists?('4567').should be_false
    end
  end

  describe '#primary_key_name' do
    it 'should return :uid if PRIMARY_KEY_NAME not set' do
      ModuleWithNoCustomPrimaryKey.send(:primary_key_name).should == :uid
    end

    it 'should return value if PRIMARY_KEY_NAME set' do
      ModuleThatIncludesRegisterMethods.send(:primary_key_name).should == :custom_uid
    end
  end

  describe "#update_data" do
    before do
      ModuleThatIncludesRegisterMethods.stub(:fetch_data_via_incremental_search)
      ModuleThatIncludesRegisterMethods.stub(:update_stale)
    end

    it "should get new records via incremental search" do
      ModuleThatIncludesRegisterMethods.should_receive(:fetch_data_via_incremental_search)
      ModuleThatIncludesRegisterMethods.update_data
    end

    it "should update stale records" do
      ModuleThatIncludesRegisterMethods.should_receive(:update_stale)
      ModuleThatIncludesRegisterMethods.update_data
    end

    it "should save run report" do
      ModuleThatIncludesRegisterMethods.should_receive(:save_run_report).with(:status => 'success')
      ModuleThatIncludesRegisterMethods.update_data
    end
  end

  describe "#update_stale" do
    it "should get uids of stale entries" do
      ModuleThatIncludesRegisterMethods.should_receive(:stale_entry_uids)
      ModuleThatIncludesRegisterMethods.update_stale
    end

    it "should update_datum for each entry yielded by stale_entries" do
      ModuleThatIncludesRegisterMethods.stub(:stale_entry_uids).and_yield('234').and_yield('666').and_yield('876')
      ModuleThatIncludesRegisterMethods.should_receive(:update_datum).with('234')
      ModuleThatIncludesRegisterMethods.should_receive(:update_datum).with('666')
      ModuleThatIncludesRegisterMethods.should_receive(:update_datum).with('876')
      ModuleThatIncludesRegisterMethods.update_stale
    end

    context "and limit passed in" do
      it "should pass on limit to #stale_entries" do
        ModuleThatIncludesRegisterMethods.should_receive(:stale_entry_uids).with(42)
        ModuleThatIncludesRegisterMethods.update_stale(42)
      end
    end
  end

  describe "#stale_entry_uids" do
    before do
      ModuleThatIncludesRegisterMethods.save_data([:custom_uid], :custom_uid => '99999')
      ModuleThatIncludesRegisterMethods.save_data([:custom_uid], :custom_uid => '5234888', :retrieved_at => (Date.today-40).to_time)
      ModuleThatIncludesRegisterMethods.save_data([:custom_uid], :custom_uid => '9234567', :retrieved_at => (Date.today-2).to_time)
      ModuleThatIncludesRegisterMethods.save_data([:custom_uid], :custom_uid => 'A094567')
    end

    it "should get entries which have not been retrieved or are more than 1 month old" do
      expect {|b| ModuleThatIncludesRegisterMethods.stale_entry_uids(&b)}.to yield_successive_args('99999', '5234888', 'A094567')
    end
  end

  describe "#update_datum for uid" do
    before do
      @dummy_time = Time.now
      @uid = '23456'
      Time.stub(:now).and_return(@dummy_time)
      @fetch_datum_response = 'some really useful data'
      # @processed_data = ModuleThatIncludesRegisterMethods.process_datum(@fetch_datum_response)
      @processed_data = {:foo => 'bar'}
      ModuleThatIncludesRegisterMethods.stub(:fetch_datum).and_return(@fetch_datum_response)
      ModuleThatIncludesRegisterMethods.stub(:process_datum).and_return(@processed_data)
      @processed_data_with_retrieved_at_and_uid = @processed_data.merge(:custom_uid => @uid, :retrieved_at => @dummy_time.to_s)
      ModuleThatIncludesRegisterMethods.stub(:save_data)
    end

    it "should fetch_datum for company number" do
      ModuleThatIncludesRegisterMethods.should_receive(:fetch_datum).with(@uid).and_return(@fetch_datum_response)
      ModuleThatIncludesRegisterMethods.update_datum(@uid)
    end

    context "and nothing returned from fetch_datum" do
      before do
        ModuleThatIncludesRegisterMethods.stub(:fetch_datum) # => nil
      end

      it "should not process_datum" do
        ModuleThatIncludesRegisterMethods.should_not_receive(:process_datum)
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      it "should not save data" do
        ModuleThatIncludesRegisterMethods.should_not_receive(:save_data)
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      it "should return nil" do
        ModuleThatIncludesRegisterMethods.update_datum(@uid).should be_nil
      end

    end

    context 'and data returned from fetch_datum' do
      it "should process_datum returned from fetching" do
        ModuleThatIncludesRegisterMethods.should_receive(:process_datum).with(@fetch_datum_response)
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      it "should prepare processed data for saving including timestamp" do
        ModuleThatIncludesRegisterMethods.should_receive(:prepare_for_saving).with(hash_including(@processed_data_with_retrieved_at_and_uid)).and_call_original
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      it "should include data in data to be prepared for saving" do
        ModuleThatIncludesRegisterMethods.should_receive(:prepare_for_saving).with(hash_including(:data => @fetch_datum_response)).and_call_original
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      it "should save prepared_data" do
        ModuleThatIncludesRegisterMethods.stub(:prepare_for_saving).and_return({:foo => 'some prepared data'})

        ModuleThatIncludesRegisterMethods.should_receive(:insert_or_update).with([:custom_uid], hash_including(:foo => 'some prepared data'))
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      it "should return data including uid" do
        ModuleThatIncludesRegisterMethods.update_datum(@uid).should == @processed_data_with_retrieved_at_and_uid
      end

      it "should not output jsonified processed data by default" do
        ModuleThatIncludesRegisterMethods.should_not_receive(:puts).with(@processed_data_with_retrieved_at_and_uid.to_json)
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      it "should output jsonified processed data to STDOUT if passed true as second argument" do
        ModuleThatIncludesRegisterMethods.should_receive(:puts).with(@processed_data_with_retrieved_at_and_uid.to_json)
        ModuleThatIncludesRegisterMethods.update_datum(@uid, true)
      end


      context "and exception raised" do
        before do
          ModuleThatIncludesRegisterMethods.stub(:process_datum).and_raise('something went wrong')
        end

        it "should output error message if true passes as second argument" do
          ModuleThatIncludesRegisterMethods.should_receive(:puts).with(/error.+went wrong/m)
          ModuleThatIncludesRegisterMethods.update_datum(@uid, true)
        end

        it "should return nil if true not passed as second argument" do
          ModuleThatIncludesRegisterMethods.update_datum(@uid).should be_nil
        end

        it "should output error message if true not passed as second argument" do
          ModuleThatIncludesRegisterMethods.should_not_receive(:puts).with(/error/)
          ModuleThatIncludesRegisterMethods.update_datum(@uid).should be_nil
        end
      end
    end
  end

  describe '#registry_url for uid' do
    it 'should get computed_registry_url' do
      ModuleThatIncludesRegisterMethods.should_receive(:computed_registry_url).with('338811').and_return('http://some.url')
      ModuleThatIncludesRegisterMethods.registry_url('338811').should == 'http://some.url'
    end

    context "and computed_registry_url returns nil" do
      it 'should get registry_url_from_db' do
        ModuleThatIncludesRegisterMethods.stub(:computed_registry_url)
        ModuleThatIncludesRegisterMethods.should_receive(:registry_url_from_db).with('338811').and_return('http://another.url')
        ModuleThatIncludesRegisterMethods.registry_url('338811').should == 'http://another.url'
      end
    end
  end

end