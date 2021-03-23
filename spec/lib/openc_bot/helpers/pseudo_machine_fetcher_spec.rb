# frozen_string_literal: true

require "spec_helper"
require "openc_bot"
require "openc_bot/helpers/pseudo_machine_fetcher"
require "openc_bot/helpers/persistence_handler"

module ModuleThatIncludesPseudoMachineFetcher
  extend OpencBot
  extend OpencBot::Helpers::PseudoMachineFetcher
end

describe OpencBot::Helpers::PseudoMachineFetcher do
  context "when a module that includes PseudoMachineFetcher" do
    it "has #run method" do
      expect(ModuleThatIncludesPseudoMachineFetcher).to respond_to(:run)
    end

    it "includes PersistenceHandler methods" do
      expect(ModuleThatIncludesPseudoMachineFetcher).to respond_to(:persist)
    end

    it "includes register_methods" do
      expect(ModuleThatIncludesPseudoMachineFetcher).to respond_to(:fetch_data)
    end
  end
end
