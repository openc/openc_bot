# frozen_string_literal: true

require_relative "../../../spec_helper"
require_relative "../../../dummy_classes/foo_bot"
require "openc_bot"
require "openc_bot/company_fetcher_bot"
require "rake"
require "openc_bot/tasks"

xdescribe SruRequestJob do # don't support SRU anymore
  describe "#perform" do
    let(:params) do
      {
        "company_number" => "16327097",
        "requested_at" => Time.now.utc,
        "openc_env" => "development",
      }
    end

    before do
      allow(described_class).to receive(:callable_from_file_name).and_return(FooBot)
      ENV["QUEUE"] = "sru_request_us_dc"
      allow(FooBot).to receive(:inferred_jurisdiction_code).and_return("us_dc")
      allow(SingleRecordUpdateJob).to receive(:enqueue)
    end

    context "when update_datum is successful" do
      before do
        allow(FooBot).to receive(:update_datum).and_return("foo" => "bar")

        described_class.perform(params)
      end

      it "calls update_datum in the FooBot runner" do
        expect(FooBot).to have_received(:update_datum).with("16327097", false)
      end

      it "sends SRU json output on the response queue" do
        expect(SingleRecordUpdateJob).to have_received(:enqueue).with(
          jurisdiction_code: "us_dc",
          company_number: "16327097",
          output: { "foo" => "bar" }.to_json,
        )
      end
    end

    context "when any error occurs in the update_datum logic" do
      let(:sru_error) { RuntimeError.new("Failed updating record") }

      before do
        allow(FooBot).to receive(:update_datum).and_raise(sru_error)

        described_class.perform(params)
      end

      it "sends the exception details as json on the response queue" do
        expect(SingleRecordUpdateJob).to have_received(:enqueue).with(
          jurisdiction_code: "us_dc",
          company_number: "16327097",
          output: { "error" => { "klass" => "RuntimeError", "message" => "Failed updating record", "backtrace" => sru_error.backtrace } }.to_json,
        )
      end
    end
  end
end
