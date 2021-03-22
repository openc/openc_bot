# frozen_string_literal: true

require "spec_helper"
require "openc_bot"
require "openc_bot/helpers/pseudo_machine_fetcher"
# require "openc_bot/helpers/incremental_search"

module ModuleThatIncludesPseudoMachineFetcher
  extend OpencBot
  extend OpencBot::Helpers::PseudoMachineFetcher
end

describe "a module that includes PseudoMachineFetcher" do
  before do
    # allow(ModuleThatIncludesIncrementalSearch).to receive(:sqlite_magic_connection).and_return(test_database_connection)
  end

  after do
    # remove_test_database
  end

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
