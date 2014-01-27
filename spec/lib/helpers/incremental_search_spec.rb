# encoding: UTF-8
require_relative '../../spec_helper'
require 'openc_bot'
require 'openc_bot/helpers/incremental_search'

module ModuleThatIncludesIncrementalSearch
  extend OpencBot
  extend OpencBot::Helpers::IncrementalSearch
  PRIMARY_KEY_NAME = :custom_uid
end

module ModuleWithNoCustomPrimaryKey
  extend OpencBot
  extend OpencBot::Helpers::IncrementalSearch
end

describe 'a module that includes IncrementalSearch' do

  before do
    ModuleThatIncludesIncrementalSearch.stub(:sqlite_magic_connection).and_return(test_database_connection)
  end

  after do
    remove_test_database
  end

  it "should have #increment_number method" do
    ModuleThatIncludesIncrementalSearch.should respond_to(:increment_number)
  end

  describe "increment_number" do
    it "should increase integer as number" do
      ModuleThatIncludesIncrementalSearch.increment_number('234567').should == '234568'
      ModuleThatIncludesIncrementalSearch.increment_number('999').should == '1000'
      ModuleThatIncludesIncrementalSearch.increment_number('000123').should == '000124'
    end

    it "should convert numbers to string" do
      ModuleThatIncludesIncrementalSearch.increment_number(234567).should == '234568'
    end

    it "should increase number prefixed by string" do
      ModuleThatIncludesIncrementalSearch.increment_number('B123456').should == 'B123457'
      ModuleThatIncludesIncrementalSearch.increment_number('B000456').should == 'B000457'
      ModuleThatIncludesIncrementalSearch.increment_number('B-999').should == 'B-1000'
      ModuleThatIncludesIncrementalSearch.increment_number('B-000999').should == 'B-001000'
    end

    it "should increase number suffixed by string" do
      ModuleThatIncludesIncrementalSearch.increment_number('123456B').should == '123457B'
      ModuleThatIncludesIncrementalSearch.increment_number('B000456B').should == 'B000457B'
      ModuleThatIncludesIncrementalSearch.increment_number('999-B').should == '1000-B'
      ModuleThatIncludesIncrementalSearch.increment_number('000999-B').should == '001000-B'
    end

    context "and number to increment given as option" do
      it "should increment by given number" do
        ModuleThatIncludesIncrementalSearch.increment_number('234567', 4).should == '234571'
        ModuleThatIncludesIncrementalSearch.increment_number('999', 4).should == '1003'
        ModuleThatIncludesIncrementalSearch.increment_number('000123', 4).should == '000127'
        ModuleThatIncludesIncrementalSearch.increment_number('B123456', 3).should == 'B123459'
        ModuleThatIncludesIncrementalSearch.increment_number('B000456', 3).should == 'B000459'
        ModuleThatIncludesIncrementalSearch.increment_number('B-999', 4).should == 'B-1003'
        ModuleThatIncludesIncrementalSearch.increment_number('B-000999', 4).should == 'B-001003'
        ModuleThatIncludesIncrementalSearch.increment_number('123456B',3).should == '123459B'
        ModuleThatIncludesIncrementalSearch.increment_number('B000456B',3).should == 'B000459B'
        ModuleThatIncludesIncrementalSearch.increment_number('999-B',4).should == '1003-B'
        ModuleThatIncludesIncrementalSearch.increment_number('000999-B',4).should == '001003-B'
      end

    end

    context "and negative number to increment given as option" do
      it "should increment by given number" do
        ModuleThatIncludesIncrementalSearch.increment_number('234567', -3).should == '234564'
        ModuleThatIncludesIncrementalSearch.increment_number('1002', -3).should == '999'
        ModuleThatIncludesIncrementalSearch.increment_number('000127', -3).should == '000124'
        ModuleThatIncludesIncrementalSearch.increment_number('B123459', -3).should == 'B123456'
        ModuleThatIncludesIncrementalSearch.increment_number('B000459', -3).should == 'B000456'
        ModuleThatIncludesIncrementalSearch.increment_number('B-1003', -4).should == 'B-999'
        ModuleThatIncludesIncrementalSearch.increment_number('B-000999', -3).should == 'B-000996'
        ModuleThatIncludesIncrementalSearch.increment_number('123459B', -3).should == '123456B'
        ModuleThatIncludesIncrementalSearch.increment_number('B000459B', -3).should == 'B000456B'
        ModuleThatIncludesIncrementalSearch.increment_number('1003-B', -4).should == '999-B'
        ModuleThatIncludesIncrementalSearch.increment_number('001003-B', -4).should == '000999-B'
      end

    end
  end

  it "should have #incremental_search method" do
    ModuleThatIncludesIncrementalSearch.should respond_to(:incremental_search)
  end

  describe '#incremental_search' do
    before do
      ModuleThatIncludesIncrementalSearch.stub(:create_new_company)
      ModuleThatIncludesIncrementalSearch.stub(:max_failed_count => 0)
    end

    it 'should iterate with prefixes, incrementing digits' do
      ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('12345', anything).and_return(:entry_1)
      ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('12346', anything).and_return(:entry_2)
      ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('12347', anything).and_return(nil)
      ModuleThatIncludesIncrementalSearch.should_not_receive(:update_datum).with('12348', anything)
      ModuleThatIncludesIncrementalSearch.incremental_search('12345')
    end

    it 'should use increment_number to, er, increment number' do
      ModuleThatIncludesIncrementalSearch.stub(:update_datum).and_return(:entry_1)
      ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('25632', anything).and_return(nil)
      ModuleThatIncludesIncrementalSearch.should_receive(:increment_number).with('12345').and_return('34567')
      ModuleThatIncludesIncrementalSearch.should_receive(:increment_number).with('34567').and_return('76543')
      ModuleThatIncludesIncrementalSearch.should_receive(:increment_number).with('76543').and_return('25632')
      ModuleThatIncludesIncrementalSearch.incremental_search('12345')
    end

    it 'should get company details for given company number and subsequent company numbers until nil is returned more than max count' do
      ModuleThatIncludesIncrementalSearch.stub(:max_failed_count => 2)
      ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234568', anything).and_return(:entry_1)
      ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234569', anything).and_return(:entry_2)
      ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234570', anything).and_return(nil)
      ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234571', anything).and_return(nil)
      ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234572', anything).and_return(:entry_3)
      ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234573', anything).and_return(nil)
      ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234574', anything).and_return(nil)
      ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234575', anything).and_return(nil)
      ModuleThatIncludesIncrementalSearch.should_not_receive(:update_datum).with('1234576', anything)
      ModuleThatIncludesIncrementalSearch.incremental_search('1234568')
    end

    it 'should return last good number' do
      ModuleThatIncludesIncrementalSearch.stub(:max_failed_count => 2)
      ModuleThatIncludesIncrementalSearch.stub(:update_datum).with('1234568', anything).and_return(:entry_1)
      ModuleThatIncludesIncrementalSearch.stub(:update_datum).with('1234569', anything).and_return(:entry_2)
      ModuleThatIncludesIncrementalSearch.stub(:update_datum).with('1234570', anything).and_return(nil)
      ModuleThatIncludesIncrementalSearch.stub(:update_datum).with('1234571', anything).and_return(nil)
      ModuleThatIncludesIncrementalSearch.stub(:update_datum).with('1234572', anything).and_return(:entry_3)
      ModuleThatIncludesIncrementalSearch.stub(:update_datum).with('1234573', anything).and_return(nil)
      ModuleThatIncludesIncrementalSearch.stub(:update_datum).with('1234574', anything).and_return(nil)
      ModuleThatIncludesIncrementalSearch.stub(:update_datum).with('1234575', anything).and_return(nil)
      ModuleThatIncludesIncrementalSearch.incremental_search('1234568').should == '1234572'
    end

    it 'should return given number if no successful results' do
      ModuleThatIncludesIncrementalSearch.stub(:max_failed_count => 2)
      ModuleThatIncludesIncrementalSearch.stub(:update_datum).and_return(nil)
      ModuleThatIncludesIncrementalSearch.incremental_search('1234568').should == '1234568'
    end

    it 'should pass on any options' do
      pending 'deciding whether this is useful (implementation carried over from openc)'
      ModuleThatIncludesIncrementalSearch.stub(:update_datum).with(anything, :foo => 'bar')
      ModuleThatIncludesIncrementalSearch.incremental_search('1234568', :foo => 'bar')
    end

    context 'and :skip_existing_entries passed in' do
      before do
        ModuleThatIncludesIncrementalSearch.stub(:datum_exists?).and_return(false)
        ModuleThatIncludesIncrementalSearch.stub(:datum_exists?).with('1234569').and_return(true)
        ModuleThatIncludesIncrementalSearch.stub(:datum_exists?).with('1234571').and_return(true)
      end

      it "should not update_datum for existing entries" do
        ModuleThatIncludesIncrementalSearch.stub(:max_failed_count => 2)
        ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234568', anything).and_return(:entry_1)
        ModuleThatIncludesIncrementalSearch.should_not_receive(:update_datum).with('1234569', anything)
        ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234570', anything).and_return(nil)
        ModuleThatIncludesIncrementalSearch.should_not_receive(:update_datum).with('1234571', anything)
        ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234572', anything).and_return(:entry_3)
        ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234573', anything).and_return(nil)
        ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234574', anything).and_return(nil)
        ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234575', anything).and_return(nil)
        ModuleThatIncludesIncrementalSearch.should_not_receive(:update_datum).with('1234576', anything)
        ModuleThatIncludesIncrementalSearch.incremental_search('1234568', :skip_existing_entries => true)
      end

      it "should reset error count when existing entry found" do
        ModuleThatIncludesIncrementalSearch.stub(:max_failed_count => 1)
        ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234568', anything).and_return(nil)
        ModuleThatIncludesIncrementalSearch.should_not_receive(:update_datum).with('1234569', anything)
        ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234570', anything).and_return(nil)
        ModuleThatIncludesIncrementalSearch.should_not_receive(:update_datum).with('1234571', anything)
        ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234572', anything).and_return(:entry_3)
        ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234573', anything).and_return(nil)
        ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('1234574', anything).and_return(nil)
        ModuleThatIncludesIncrementalSearch.should_not_receive(:update_datum).with('1234575', anything)
        ModuleThatIncludesIncrementalSearch.incremental_search('1234568', :skip_existing_entries => true)
      end
    end

    context 'and offset passed in as option' do
      it "should get entries beginning from given number adjusted by offset" do
        ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('12342', anything).and_return(:entry_1)
        ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('12343', anything).and_return(:entry_2)
        ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('12344', anything).and_return(nil)
        ModuleThatIncludesIncrementalSearch.should_not_receive(:update_datum).with('12345', anything)
        ModuleThatIncludesIncrementalSearch.incremental_search('12345', :offset => -3)
      end
    end
  end

  describe "#datum_exists?" do
    before do
      ModuleThatIncludesIncrementalSearch.stub(:select).and_return([])

    end

    it "should select_data from database" do
      expected_sql_query = "ocdata.custom_uid FROM ocdata WHERE custom_uid = '?' LIMIT 1"
      ModuleThatIncludesIncrementalSearch.should_receive(:select).with(expected_sql_query, '4567').and_return([])
      ModuleThatIncludesIncrementalSearch.datum_exists?('4567')
    end

    it "should return true if result returned" do
      ModuleThatIncludesIncrementalSearch.stub(:select).and_return([{'custom_uid' => '4567'}])

      ModuleThatIncludesIncrementalSearch.datum_exists?('4567').should be_true
    end

    it "should return false if result returned" do
      ModuleThatIncludesIncrementalSearch.datum_exists?('4567').should be_false
    end
  end

  describe '#incremental_rewind_count' do
    it 'should return nil if INCREMENTAL_REWIND_COUNT not set' do
      ModuleThatIncludesIncrementalSearch.send(:incremental_rewind_count).should be_nil
    end

    it 'should return value if INCREMENTAL_REWIND_COUNT set' do
      stub_const("ModuleThatIncludesIncrementalSearch::INCREMENTAL_REWIND_COUNT", 42)
      ModuleThatIncludesIncrementalSearch.send(:incremental_rewind_count).should == ModuleThatIncludesIncrementalSearch::INCREMENTAL_REWIND_COUNT
    end
  end

  describe '#primary_key_name' do
    it 'should return :uid if PRIMARY_KEY_NAME not set' do
      ModuleWithNoCustomPrimaryKey.send(:primary_key_name).should == :uid
    end

    it 'should return value if PRIMARY_KEY_NAME set' do
      ModuleThatIncludesIncrementalSearch.send(:primary_key_name).should == :custom_uid
    end
  end

  describe '#max_failed_count' do
    it 'should return 0 if MAX_FAILED_COUNT not set' do
      ModuleThatIncludesIncrementalSearch.send(:max_failed_count).should == 10
    end

    it 'should return value if MAX_FAILED_COUNT set' do
      stub_const("ModuleThatIncludesIncrementalSearch::MAX_FAILED_COUNT", 42)
      ModuleThatIncludesIncrementalSearch.send(:max_failed_count).should == ModuleThatIncludesIncrementalSearch::MAX_FAILED_COUNT
    end
  end

  describe "entity_uid_prefixes" do
    context 'and no ENTITY_UID_PREFIXES constant' do
      it "should return array containing nil" do
        ModuleThatIncludesIncrementalSearch.entity_uid_prefixes.should == [nil]
      end
    end

    context 'and has ENTITY_UID_PREFIXES constant' do
      it "should return ENTITY_UID_PREFIXES" do
        stub_const("ModuleThatIncludesIncrementalSearch::ENTITY_UID_PREFIXES", ['A','X'])
        ModuleThatIncludesIncrementalSearch.entity_uid_prefixes.should == ModuleThatIncludesIncrementalSearch::ENTITY_UID_PREFIXES
      end
    end
  end

  describe '#get_new' do
    before do
      @most_recent_companies = ['03456789', 'A12345']
      ModuleThatIncludesIncrementalSearch.stub(:highest_entry_uids).and_return(@most_recent_companies)
      ModuleThatIncludesIncrementalSearch.stub(:incremental_search)
    end

    it 'should find highest_entry_uids' do
      ModuleThatIncludesIncrementalSearch.should_receive(:highest_entry_uids)

      ModuleThatIncludesIncrementalSearch.get_new
    end

    context 'and highest_entry_uids returns nil' do
      before do
        ModuleThatIncludesIncrementalSearch.stub(:highest_entry_uids) #  => nil
      end

      it 'should not do incremental_search' do
        ModuleThatIncludesIncrementalSearch.should_not_receive(:incremental_search)

        ModuleThatIncludesIncrementalSearch.get_new
      end

      it 'should not update cached highest_entry_uid value' do
        ModuleThatIncludesIncrementalSearch.should_not_receive(:save_var)

        ModuleThatIncludesIncrementalSearch.get_new
      end
    end

    context 'and highest_entry_uids returns values' do
      before do
        ModuleThatIncludesIncrementalSearch.stub(:highest_entry_uids).and_return(@most_recent_companies)
      end

      it 'should do incremental_search starting at each highest company number' do
        ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('03456789', {})
        ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('A12345', {})

        ModuleThatIncludesIncrementalSearch.get_new
      end

      it 'should save highest_entry_uids' do
        ModuleThatIncludesIncrementalSearch.stub(:incremental_search).with('03456789', anything).and_return('0345999')
        ModuleThatIncludesIncrementalSearch.stub(:incremental_search).with('A12345', anything).and_return('A234567')
        ModuleThatIncludesIncrementalSearch.should_receive(:save_var).with(:highest_entry_uids, ['0345999','A234567'])

        ModuleThatIncludesIncrementalSearch.get_new
      end

      context 'and options passed to get_new' do
        it "should pass them on to incremental search" do
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('03456789', :foo => 'bar')
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('A12345', :foo => 'bar')
          ModuleThatIncludesIncrementalSearch.get_new(:foo => 'bar')
        end
      end

      context 'and library has incremental_rewind_count' do
        before do
          ModuleThatIncludesIncrementalSearch.stub(:incremental_rewind_count).and_return(42)
        end

        it "should pass negated version on to incremental search as offset" do
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('03456789', hash_including(:offset => -42))
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('A12345', hash_including(:offset => -42))
          ModuleThatIncludesIncrementalSearch.get_new
        end

        it "should ask to skip_existing_companies on incremental search by default" do
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('03456789', hash_including(:skip_existing_entries => true))
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('A12345', hash_including(:skip_existing_entries => true))
          ModuleThatIncludesIncrementalSearch.get_new
        end

        it "should not ask to skip_existing_companies on incremental search if requested not to" do
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('03456789', hash_including(:skip_existing_entries => false))
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('A12345', hash_including(:skip_existing_entries => false))
          ModuleThatIncludesIncrementalSearch.get_new(:skip_existing_entries => false)
        end
      end

    end

    context 'and highest_entry_uids passed in options' do
      it "should not find highest_entry_uids" do
        ModuleThatIncludesIncrementalSearch.should_not_receive(:highest_entry_uids)

        ModuleThatIncludesIncrementalSearch.get_new(:highest_entry_uids => ['1234', '6543'])
      end

      it 'should do incremental_search starting at provided highest company numbers' do
        ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('1234', {})
        ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('6543', {})

        ModuleThatIncludesIncrementalSearch.get_new(:highest_entry_uids => ['1234', '6543'])
      end
    end
  end

  describe '#highest_entry_uids' do
    before do
      # ModuleThatIncludesIncrementalSearch.cache_store.del(ModuleThatIncludesIncrementalSearch.cache_key(:highest_entry_uids))
      ModuleThatIncludesIncrementalSearch.stub(:highest_entry_uid_result).and_return('553311')
      ModuleThatIncludesIncrementalSearch.stub(:entity_uid_prefixes).and_return(['H', 'P'])
    end

    context 'and highest_entry_uids not set in cache' do
      before do
      end

      it 'should get highest_entry_uid_result for each prefix' do
        ModuleThatIncludesIncrementalSearch.should_receive(:highest_entry_uid_result).with(:prefix => 'H').with(:prefix => 'P')
        ModuleThatIncludesIncrementalSearch.highest_entry_uids
      end

      it 'should return highest uid for jurisdiction_code' do
        ModuleThatIncludesIncrementalSearch.should_receive(:highest_entry_uid_result).with(:prefix => 'H').and_return('H553311')
        ModuleThatIncludesIncrementalSearch.should_receive(:highest_entry_uid_result).with(:prefix => 'P').and_return('P12345')
        ModuleThatIncludesIncrementalSearch.highest_entry_uids.should == ['H553311', 'P12345']
      end
    end

    context 'and highest_entry_uid_result returns nil value' do
      before do
        ModuleThatIncludesIncrementalSearch.stub(:highest_entry_uid_result).with(:prefix => 'H').and_return(nil)
        ModuleThatIncludesIncrementalSearch.stub(:highest_entry_uid_result).with(:prefix => 'P').and_return('P12345')
      end

      it "should return only nil values" do
        ModuleThatIncludesIncrementalSearch.highest_entry_uids.should == ['P12345']
      end
    end

    context 'and highest_uid in cache' do
      before do
        @cached_result = '765432'
        ModuleThatIncludesIncrementalSearch.save_var('highest_entry_uids', @cached_result)
      end

      it 'should not search for companies' do
        ModuleThatIncludesIncrementalSearch.should_not_receive('highest_entry_uid_result')
        ModuleThatIncludesIncrementalSearch.highest_entry_uids
      end

      it 'should return cached highest_entry_uid' do
        ModuleThatIncludesIncrementalSearch.highest_entry_uids.should == @cached_result
      end

      context 'and blank value returned for cached value' do
        before do
          ModuleThatIncludesIncrementalSearch.save_var('highest_entry_uids', ['H553311',''])
        end

        it "should ignore cached value" do
          ModuleThatIncludesIncrementalSearch.should_receive(:highest_entry_uid_result).with(:prefix => 'H').with(:prefix => 'P')

          ModuleThatIncludesIncrementalSearch.highest_entry_uids
        end
      end
    end

  end

  describe '#highest_entry_uid_result' do
    context "in general" do
      before do
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => '99999')
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => '5234888')
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => '9234567')
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => 'A094567')
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => 'A234567')
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => 'SL34567')
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => 'SL34999')
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => 'H9999')
        ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => '5234567')
      end

      context 'and no options passed' do
        it 'should return highest uid as number for jurisdiction_code' do
          ModuleThatIncludesIncrementalSearch.highest_entry_uid_result.should == '9234567'
        end
      end

      context 'and prefix passed in options' do
        it 'should return highest uid as number for jurisdiction_code' do
          ModuleThatIncludesIncrementalSearch.highest_entry_uid_result(:prefix => 'A').should == 'A234567'
          ModuleThatIncludesIncrementalSearch.highest_entry_uid_result(:prefix => 'SL').should == 'SL34999'
        end
      end
    end

    context "and no database created yet" do
      it "should return 0" do
        ModuleThatIncludesIncrementalSearch.highest_entry_uid_result.should == '0'
      end

      it "should return prefix plus 0 if prefix given" do
        ModuleThatIncludesIncrementalSearch.highest_entry_uid_result(:prefix => 'A').should == 'A0'
      end
    end
  end

  describe "#update_data" do
    before do
      ModuleThatIncludesIncrementalSearch.stub(:get_new)
      ModuleThatIncludesIncrementalSearch.stub(:update_stale)
    end

    it "should get new records" do
      ModuleThatIncludesIncrementalSearch.should_receive(:get_new)
      ModuleThatIncludesIncrementalSearch.update_data
    end

    it "should update stale records" do
      ModuleThatIncludesIncrementalSearch.should_receive(:update_stale)
      ModuleThatIncludesIncrementalSearch.update_data
    end

    it "should save run report" do
      ModuleThatIncludesIncrementalSearch.should_receive(:save_run_report).with(:status => 'success')
      ModuleThatIncludesIncrementalSearch.update_data
    end
  end

  describe "#update_stale" do
    it "should get uids of stale entries" do
      ModuleThatIncludesIncrementalSearch.should_receive(:stale_entry_uids)
      ModuleThatIncludesIncrementalSearch.update_stale
    end

    it "should update_datum for each entry yielded by stale_entries" do
      ModuleThatIncludesIncrementalSearch.stub(:stale_entry_uids).and_yield('234').and_yield('666').and_yield('876')
      ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('234')
      ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('666')
      ModuleThatIncludesIncrementalSearch.should_receive(:update_datum).with('876')
      ModuleThatIncludesIncrementalSearch.update_stale
    end

    context "and limit passed in" do
      it "should pass on limit to #stale_entries" do
        ModuleThatIncludesIncrementalSearch.should_receive(:stale_entry_uids).with(42)
        ModuleThatIncludesIncrementalSearch.update_stale(42)
      end
    end
  end

  describe "#stale_entry_uids" do
    before do
      ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => '99999')
      ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => '5234888', :retrieved_at => (Date.today-40).to_time)
      ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => '9234567', :retrieved_at => (Date.today-2).to_time)
      ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => 'A094567')
    end

    it "should get entries which have not been retrieved or are more than 1 month old" do
      expect {|b| ModuleThatIncludesIncrementalSearch.stale_entry_uids(&b)}.to yield_successive_args('99999', '5234888', 'A094567')
    end
  end

  describe "#update_datum for uid" do
    before do
      @dummy_time = Time.now
      Time.stub(:now).and_return(@dummy_time)
      @fetch_datum_response = 'some really useful data'
      # @processed_data = ModuleThatIncludesIncrementalSearch.process_datum(@fetch_datum_response)
      @processed_data = {:foo => 'bar'}
      ModuleThatIncludesIncrementalSearch.stub(:fetch_datum).and_return(@fetch_datum_response)
      ModuleThatIncludesIncrementalSearch.stub(:process_datum).and_return(@processed_data)
      @processed_data_with_retrieved_at = @processed_data.merge(:retrieved_at => @dummy_time.to_s)
      ModuleThatIncludesIncrementalSearch.stub(:save_data)
    end

    it "should fetch_datum for company number" do
      ModuleThatIncludesIncrementalSearch.should_receive(:fetch_datum).with('23456').and_return(@fetch_datum_response)
      ModuleThatIncludesIncrementalSearch.update_datum('23456')
    end

    context "and nothing returned from fetch_datum" do
      before do
        ModuleThatIncludesIncrementalSearch.stub(:fetch_datum) # => nil
      end

      it "should not process_datum" do
        ModuleThatIncludesIncrementalSearch.should_not_receive(:process_datum)
        ModuleThatIncludesIncrementalSearch.update_datum('23456')
      end

      it "should not save data" do
        ModuleThatIncludesIncrementalSearch.should_not_receive(:save_data)
        ModuleThatIncludesIncrementalSearch.update_datum('23456')
      end

      it "should return nil" do
        ModuleThatIncludesIncrementalSearch.update_datum('23456').should be_nil
      end

    end

    context 'and data returned from fetch_datum' do
      it "should process_datum returned from fetching" do
        ModuleThatIncludesIncrementalSearch.should_receive(:process_datum).with(@fetch_datum_response)
        ModuleThatIncludesIncrementalSearch.update_datum('23456')
      end

      it "should prepare processed data for saving including timestamp" do
        ModuleThatIncludesIncrementalSearch.should_receive(:prepare_for_saving).with(@processed_data_with_retrieved_at).and_call_original
        ModuleThatIncludesIncrementalSearch.update_datum('23456')
      end

      it "should save prepared_data" do
        ModuleThatIncludesIncrementalSearch.stub(:prepare_for_saving).and_return({:foo => 'some prepared data'})

        ModuleThatIncludesIncrementalSearch.should_receive(:save_data).with([:custom_uid], hash_including(:foo => 'some prepared data'))
        ModuleThatIncludesIncrementalSearch.update_datum('23456')
      end

      it "should return data" do
        ModuleThatIncludesIncrementalSearch.update_datum('23456').should == @processed_data_with_retrieved_at
      end

      it "should include uid in data" do
        ModuleThatIncludesIncrementalSearch.stub(:prepare_for_saving).and_return({:foo => 'some prepared data'})
        ModuleThatIncludesIncrementalSearch.should_receive(:save_data).with(anything, hash_including(:custom_uid => '23456'))
        ModuleThatIncludesIncrementalSearch.update_datum('23456').should == @processed_data_with_retrieved_at
      end

      it "should not output jsonified processed data by default" do
        ModuleThatIncludesIncrementalSearch.should_not_receive(:puts).with(@processed_data_with_retrieved_at.to_json)
        ModuleThatIncludesIncrementalSearch.update_datum('23456')
      end

      it "should output jsonified processed data to STDOUT if passed true as second argument" do
        ModuleThatIncludesIncrementalSearch.should_receive(:puts).with(@processed_data_with_retrieved_at.to_json)
        ModuleThatIncludesIncrementalSearch.update_datum('23456', true)
      end



      context "and exception raised" do
        before do
          ModuleThatIncludesIncrementalSearch.stub(:process_datum).and_raise('something went wrong')
        end

        it "should output error message if true passes as second argument" do
          ModuleThatIncludesIncrementalSearch.should_receive(:puts).with(/error.+went wrong/m)
          ModuleThatIncludesIncrementalSearch.update_datum('23456', true)
        end

        it "should return nil if true not passed as second argument" do
          ModuleThatIncludesIncrementalSearch.update_datum('23456').should be_nil
        end

        it "should output error message if true not passed as second argument" do
          ModuleThatIncludesIncrementalSearch.should_not_receive(:puts).with(/error/)
          ModuleThatIncludesIncrementalSearch.update_datum('23456').should be_nil
        end
      end
    end
  end

end