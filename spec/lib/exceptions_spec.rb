# encoding: UTF-8
require_relative '../spec_helper'
require 'openc_bot'

describe OpencBot::Exceptions do

  describe OpencBot::OpencBotError do

    it 'should have StandardError as superclass' do
      OpencBot::OpencBotError.superclass.should == StandardError
    end
  end

  describe OpencBot::RecordInvalid do

    it 'should have OpencBotError as superclass' do
      OpencBot::RecordInvalid.superclass.should == OpencBot::OpencBotError
    end

    it "should have set validation_errors accessor on instantiation" do
      error = OpencBot::RecordInvalid.new(:some_validation_error)
      error.validation_errors.should == :some_validation_error
    end
  end
end
