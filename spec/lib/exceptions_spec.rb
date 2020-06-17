# frozen_string_literal: true

require_relative "../spec_helper"
require "openc_bot"
require "json-schema"

describe "OpencBot exceptions" do
  describe OpencBot::OpencBotError do
    it "has StandardError as superclass" do
      expect(described_class.superclass).to eq(StandardError)
    end
  end

  describe OpencBot::RecordInvalid do
    before do
      @schema = File.join(File.dirname(__FILE__), "..", "..", "schemas", "schemas", "company-schema.json")
      @record = {
        name: "Foo Inc",
      }

      @validation_errors = JSON::Validator.fully_validate(@schema, @record.to_json, errors_as_objects: true)

      @error = described_class.new(@validation_errors)
    end

    it "has OpencBotError as superclass" do
      expect(described_class.superclass).to eq(OpencBot::OpencBotError)
    end

    it "has set validation_errors accessor on instantiation" do
      expect(@error.validation_errors).to eq(@validation_errors)
    end

    describe "message" do
      it "includes validation_errors" do
        expect(@error.message).to match "Validation failed"
        expect(@error.message).to match "did not contain a required property of 'company_number'"
        expect(@error.message).to match "did not contain a required property of 'jurisdiction_code'"
      end

      # context 'and given message when instantiated' do
      #   @error = OpencBot::RecordInvalid.new(@validation_errors, "some custom message").should match "some custom message"
      # end
    end
  end
end
