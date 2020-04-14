require "spec_helper"
require "openc_bot"
require "openc_bot/company_fetcher_bot"
require "openc_bot/config"

module ModuleThatIncludesConfig
  extend OpencBot
  extend OpencBot::CompanyFetcherBot
  extend OpencBot::Config
end

describe OpencBot::Config do
  let(:expected_output) { OpenStruct.new(bot_config: { foo: "bar" }) }

  describe "#set_variables" do
    before do
      allow(ModuleThatIncludesConfig).to receive(:config?).and_return(expected_output)
    end

    it "sends a request to config def" do
      ModuleThatIncludesConfig.set_variables
      expect(ModuleThatIncludesConfig).to have_received(:config?).twice
    end
  end

  describe "#db_config" do
    context "when BOTS_JSON_URL is not set" do
      it "returns nil" do
        expect(ModuleThatIncludesConfig.db_config).to eq(nil)
      end
    end

    context "when BOTS_JSON_URL is set" do
      before do
        stub_const("OpencBot::Config::BOTS_JSON_URL", "someendpoint")
        ModuleThatIncludesConfig.instance_variable_set(:@db_config, expected_output)
      end

      it "returns an object" do
        expect(ModuleThatIncludesConfig.db_config).to eq(expected_output)
      end
    end
  end

  describe "#config?" do
    context "when db_config returns an object" do
      before do
        allow(ModuleThatIncludesConfig).to receive(:db_config).and_return(expected_output)
      end

      it "returns the bot_config struct from the db_config object that is queryable" do
        expect(ModuleThatIncludesConfig.config?.foo).to eq("bar")
      end
    end

    context "when db_config does not return an object" do
      it "returns nil" do
        expect(ModuleThatIncludesConfig.config?).to eq(nil)
      end
    end
  end
end
