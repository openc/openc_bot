# encoding: UTF-8
require_relative '../spec_helper'
require 'openc_bot'
require 'json-schema'

describe 'OpencBot exceptions' do

  describe OpencBot::OpencBotError do

    it 'should have StandardError as superclass' do
      OpencBot::OpencBotError.superclass.should == StandardError
    end
  end

  describe OpencBot::RecordInvalid do
    before do
      @schema = File.join(File.dirname(__FILE__),'..','..','schemas','schemas','company-schema.json')
      @record = {
        :name => 'Foo Inc'
      }

      @validation_errors = JSON::Validator.fully_validate(@schema, @record.to_json, {:errors_as_objects => true})

      @error = OpencBot::RecordInvalid.new(@validation_errors)

    end

    it 'should have OpencBotError as superclass' do
      OpencBot::RecordInvalid.superclass.should == OpencBot::OpencBotError
    end

    it "should have set validation_errors accessor on instantiation" do
      @error.validation_errors.should == @validation_errors
    end

    describe 'message' do
      it 'should include validation_errors' do
        @error.message.should match 'Validation failed'
        @error.message.should match "did not contain a required property of 'company_number'"
        @error.message.should match "did not contain a required property of 'jurisdiction_code'"
      end

      # context 'and given message when instantiated' do
      #   @error = OpencBot::RecordInvalid.new(@validation_errors, "some custom message").should match "some custom message"
      # end
    end
  end
end
