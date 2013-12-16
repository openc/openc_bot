require 'rspec'
require 'simple_openc_bot'

module TestLicenceBot
  class LicenceRecord < SimpleOpencBot::BaseLicenceRecord
    fields :name, :type
    unique_fields :name

    def jurisdiction_classification
      type
    end
  end

  class Fetcher
    def all_records
      data = [
        {name: 'Company 1', type: 'Bank'},
        {name: 'Company 2', type: 'Insurer'},
      ]

      data.map do |datum|
        LicenceRecord.new({
          :name => datum[:name],
          :type => datum[:type],
        })
      end
    end
  end
end

describe TestLicenceBot::LicenceRecord do
  before do
    @record = TestLicenceBot::LicenceRecord.new(
      :name => 'Foo',
      :type => 'Bar',
    )
  end

  describe 'fields' do
    it 'can get attribute' do
      @record.name.should == 'Foo'
    end

    it 'can set attribute' do
      @record.name = 'Baz'
      @record.name.should == 'Baz'
    end
  end
end
