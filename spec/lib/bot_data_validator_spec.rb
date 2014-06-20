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
      OpencBot::BotDataValidator.validate(@valid_data).should be true
    end

    it 'should return false if data is not a hash' do
      OpencBot::BotDataValidator.validate(nil).should be_false
      OpencBot::BotDataValidator.validate('foo').should be_false
      OpencBot::BotDataValidator.validate(['foo']).should be_false
    end

    it 'should return false if company_data is blank' do
      OpencBot::BotDataValidator.validate(@valid_data.merge(:company => nil)).should be_false
      OpencBot::BotDataValidator.validate(@valid_data.merge(:company => '  ')).should be_false
    end

    it 'should return false if company_data is missing name' do
      OpencBot::BotDataValidator.validate(@valid_data.merge(:company => {:name => nil})).should be_false
      OpencBot::BotDataValidator.validate(@valid_data.merge(:company => {:name => ' '})).should be_false
    end

    it 'should return false if source_url is blank' do
      OpencBot::BotDataValidator.validate(@valid_data.merge(:source_url => nil)).should be_false
      OpencBot::BotDataValidator.validate(@valid_data.merge(:source_url => '  ')).should be_false
    end

    it 'should return false if data is empty' do
      OpencBot::BotDataValidator.validate(@valid_data.merge(:data => nil)).should be_false
      OpencBot::BotDataValidator.validate(@valid_data.merge(:data => [])).should be_false
    end

    it 'should return false if data is missing data_type' do
      OpencBot::BotDataValidator.validate(@valid_data.merge(:data => [{:data_type => nil,
                                                            :properties => {:foo => 'bar'}}])).should be_false
      OpencBot::BotDataValidator.validate(@valid_data.merge(:data => [{:data_type => '  ',
                                                            :properties => {:foo => 'bar'}}])).should be_false
    end

    it 'should return false if properties is blank' do
      OpencBot::BotDataValidator.validate(@valid_data.merge(:data => [{:data_type => :subsidiary_relationship,
                                                            :properties => {}}])).should be_false
      OpencBot::BotDataValidator.validate(@valid_data.merge(:data => [{:data_type => :subsidiary_relationship,
                                                            :properties => nil}])).should be_false
    end

  end
end
