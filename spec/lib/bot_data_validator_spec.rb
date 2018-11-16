# encoding: UTF-8
require_relative '../spec_helper'
require 'openc_bot'

describe OpencBot::BotDataValidator do

  describe '#validate' do
    before do
      @valid_data =
        { :company => {:name => "CENTRAL BANK", :identifier => "rssd/546544", :jurisdiction => "IA"},
          :data => [{ :data_type => :subsidiary_relationship,
                      :properties => {:foo => 'bar'}
                      },
                    { :data_type => :subsidiary_relationship,
                      :properties => { :foo => 'baz' }
                    }
                      ],
          :source_url => "http://www.ffiec.gov/nicpubweb/nicweb/OrgHierarchySearchForm.aspx?parID_RSSD=546544&parDT_END=99991231",
          :reporting_date => "2013-01-18 12:52:20"
        }


    end
    it 'should return true if data is valid' do
      expect(OpencBot::BotDataValidator.validate(@valid_data)).to be true
    end

    it 'should return false if data is not a hash' do
      expect(OpencBot::BotDataValidator.validate(nil)).to be false
      expect(OpencBot::BotDataValidator.validate('foo')).to be false
      expect(OpencBot::BotDataValidator.validate(['foo'])).to be false
    end

    it 'should return false if company_data is blank' do
      expect(OpencBot::BotDataValidator.validate(@valid_data.merge(:company => nil))).to be false
      expect(OpencBot::BotDataValidator.validate(@valid_data.merge(:company => '  '))).to be false
    end

    it 'should return false if company_data is missing name' do
      expect(OpencBot::BotDataValidator.validate(@valid_data.merge(:company => {:name => nil}))).to be false
      expect(OpencBot::BotDataValidator.validate(@valid_data.merge(:company => {:name => ' '}))).to be false
    end

    it 'should return false if source_url is blank' do
      expect(OpencBot::BotDataValidator.validate(@valid_data.merge(:source_url => nil))).to be false
      expect(OpencBot::BotDataValidator.validate(@valid_data.merge(:source_url => '  '))).to be false
    end

    it 'should return false if data is empty' do
      expect(OpencBot::BotDataValidator.validate(@valid_data.merge(:data => nil))).to be false
      expect(OpencBot::BotDataValidator.validate(@valid_data.merge(:data => []))).to be false
    end

    it 'should return false if data is missing data_type' do
      expect(OpencBot::BotDataValidator.validate(@valid_data.merge(:data => [{:data_type => nil,
                                                            :properties => {:foo => 'bar'}}]))).to be false
      expect(OpencBot::BotDataValidator.validate(@valid_data.merge(:data => [{:data_type => '  ',
                                                            :properties => {:foo => 'bar'}}]))).to be false
    end

    it 'should return false if properties is blank' do
      expect(OpencBot::BotDataValidator.validate(@valid_data.merge(:data => [{:data_type => :subsidiary_relationship,
                                                            :properties => {}}]))).to be false
      expect(OpencBot::BotDataValidator.validate(@valid_data.merge(:data => [{:data_type => :subsidiary_relationship,
                                                            :properties => nil}]))).to be false
    end

  end
end
