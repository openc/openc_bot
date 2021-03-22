# frozen_string_literal: true

require "spec_helper"
require "openc_bot"
require "openc_bot/helpers/pseudo_machine_parser"
# require "openc_bot/helpers/incremental_search"

module ModuleThatIncludesPseudoMachineParser
  extend OpencBot
  extend OpencBot::Helpers::PseudoMachineParser
end

describe "a module that includes PseudoMachineParser" do
  before do
    # allow(ModuleThatIncludesIncrementalSearch).to receive(:sqlite_magic_connection).and_return(test_database_connection)
  end

  after do
    # remove_test_database
  end

  it "has #run method" do
    expect(ModuleThatIncludesPseudoMachineParser).to respond_to(:run)
  end

  it "includes PersistenceHandler methods" do
    expect(ModuleThatIncludesPseudoMachineParser).to respond_to(:persist)
  end

  describe "input_stream" do
    it "should return 'fetcher'" do
      expect(ModuleThatIncludesPseudoMachineParser.input_stream).to eq("fetcher")
    end
  end

end
