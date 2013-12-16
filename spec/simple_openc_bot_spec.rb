require 'rspec'
require 'simple_openc_bot'

module TestLicenceBot
  extend SimpleOpencBot

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
    @initial_values_hash = {:name => 'Foo',
                            :type => 'Bar'}

    @record = TestLicenceBot::LicenceRecord.new(
      @initial_values_hash
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

  describe "#to_hash" do
    it "should output all the fields as a hash" do
      @record.to_hash.should ==  @initial_values_hash
    end
  end
end
