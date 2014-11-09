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

  describe '#incremental_rewind_count' do
    it 'should return nil if INCREMENTAL_REWIND_COUNT not set' do
      ModuleThatIncludesIncrementalSearch.send(:incremental_rewind_count).should be_nil
    end

    it 'should return value if INCREMENTAL_REWIND_COUNT set' do
      stub_const("ModuleThatIncludesIncrementalSearch::INCREMENTAL_REWIND_COUNT", 42)
      ModuleThatIncludesIncrementalSearch.send(:incremental_rewind_count).should == ModuleThatIncludesIncrementalSearch::INCREMENTAL_REWIND_COUNT
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

  describe "entity_uid_suffixes" do
    context 'and no ENTITY_UID_SUFFIXES constant' do
      it "should return array containing nil" do
        ModuleThatIncludesIncrementalSearch.entity_uid_suffixes.should == [nil]
      end
    end

    context 'and has ENTITY_UID_SUFFIXES constant' do
      it "should return ENTITY_UID_SUFFIXES" do
        stub_const("ModuleThatIncludesIncrementalSearch::ENTITY_UID_SUFFIXES", ['A','X'])
        ModuleThatIncludesIncrementalSearch.entity_uid_suffixes.should == ModuleThatIncludesIncrementalSearch::ENTITY_UID_SUFFIXES
      end
    end
  end

  describe '#fetch_data_via_incremental_search' do
    before do
      @most_recent_companies = ['03456789', 'A12345']
      ModuleThatIncludesIncrementalSearch.stub(:highest_entry_uids).and_return(@most_recent_companies)
      ModuleThatIncludesIncrementalSearch.stub(:incremental_search)
    end

    it 'should find highest_entry_uids' do
      ModuleThatIncludesIncrementalSearch.should_receive(:highest_entry_uids)

      ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search
    end

    context 'and highest_entry_uids returns nil' do
      before do
        ModuleThatIncludesIncrementalSearch.stub(:highest_entry_uids) #  => nil
      end

      it 'should not do incremental_search' do
        ModuleThatIncludesIncrementalSearch.should_not_receive(:incremental_search)

        ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search
      end

      it 'should not update cached highest_entry_uid value' do
        ModuleThatIncludesIncrementalSearch.should_not_receive(:save_var)

        ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search
      end
    end

    context 'and highest_entry_uids returns values' do
      before do
        ModuleThatIncludesIncrementalSearch.stub(:highest_entry_uids).and_return(@most_recent_companies)
      end

      it 'should do incremental_search starting at each highest company number' do
        ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('03456789', {})
        ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('A12345', {})

        ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search
      end

      it 'should save highest_entry_uids' do
        ModuleThatIncludesIncrementalSearch.stub(:incremental_search).with('03456789', anything).and_return('0345999')
        ModuleThatIncludesIncrementalSearch.stub(:incremental_search).with('A12345', anything).and_return('A234567')
        ModuleThatIncludesIncrementalSearch.should_receive(:save_var).with(:highest_entry_uids, ['0345999','A234567'])

        ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search
      end

      context 'and options passed to fetch_data_via_incremental_search' do
        it "should pass them on to incremental search" do
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('03456789', :foo => 'bar')
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('A12345', :foo => 'bar')
          ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search(:foo => 'bar')
        end
      end

      context 'and library has incremental_rewind_count' do
        before do
          ModuleThatIncludesIncrementalSearch.stub(:incremental_rewind_count).and_return(42)
        end

        it "should pass negated version on to incremental search as offset" do
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('03456789', hash_including(:offset => -42))
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('A12345', hash_including(:offset => -42))
          ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search
        end

        it "should ask to skip_existing_companies on incremental search by default" do
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('03456789', hash_including(:skip_existing_entries => true))
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('A12345', hash_including(:skip_existing_entries => true))
          ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search
        end

        it "should not ask to skip_existing_companies on incremental search if requested not to" do
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('03456789', hash_including(:skip_existing_entries => false))
          ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('A12345', hash_including(:skip_existing_entries => false))
          ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search(:skip_existing_entries => false)
        end
      end

    end

    context 'and highest_entry_uids passed in options' do
      it "should not find highest_entry_uids" do
        ModuleThatIncludesIncrementalSearch.should_not_receive(:highest_entry_uids)

        ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search(:highest_entry_uids => ['1234', '6543'])
      end

      it 'should do incremental_search starting at provided highest company numbers' do
        ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('1234', {})
        ModuleThatIncludesIncrementalSearch.should_receive(:incremental_search).with('6543', {})

        ModuleThatIncludesIncrementalSearch.fetch_data_via_incremental_search(:highest_entry_uids => ['1234', '6543'])
      end
    end
  end

  describe '#highest_entry_uids' do
    before do
      ModuleThatIncludesIncrementalSearch.stub(:highest_entry_uid_result).and_return('553311')
      ModuleThatIncludesIncrementalSearch.stub(:entity_uid_prefixes).and_return(['H', 'P'])
    end

    context 'and highest_entry_uids not set in cache' do

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

    context 'and highest_entry_uids in cache' do
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

      context 'and true passed in as argument' do
        before do
          ModuleThatIncludesIncrementalSearch.save_var('highest_entry_uids', ['H553311','P1234'])
        end

        it "should ignore cached value" do
          ModuleThatIncludesIncrementalSearch.should_receive(:highest_entry_uid_result).with(:prefix => 'H').with(:prefix => 'P')

          ModuleThatIncludesIncrementalSearch.highest_entry_uids(true)
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

      context "and suffix passed in options" do
        before do
          ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => '009802V')
          ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => '001234V')
          ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => '34567C')
          ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => '128055C')
          ModuleThatIncludesIncrementalSearch.save_data([:custom_uid], :custom_uid => '99999999')
        end

        it 'should return highest company_number for Im with prefix letter' do
          ModuleThatIncludesIncrementalSearch.highest_entry_uid_result(:suffix => 'V').should == '009802V'
          ModuleThatIncludesIncrementalSearch.highest_entry_uid_result(:suffix => 'C').should == '128055C'
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

end