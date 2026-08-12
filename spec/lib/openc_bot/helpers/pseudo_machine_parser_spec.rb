# frozen_string_literal: true

require "spec_helper"
require "openc_bot"
require "openc_bot/helpers/pseudo_machine_parser"
# require "openc_bot/helpers/incremental_search"

module ModuleThatIncludesPseudoMachineParser
  extend OpencBot
  extend OpencBot::Helpers::PseudoMachineParser
end

describe OpencBot::Helpers::PseudoMachineParser
context "when a module that includes PseudoMachineParser" do
  it "has #run method" do
    expect(ModuleThatIncludesPseudoMachineParser).to respond_to(:run)
  end

  it "includes PersistenceHandler methods" do
    expect(ModuleThatIncludesPseudoMachineParser).to respond_to(:persist)
  end

  it "return's fetcher" do
    expect(ModuleThatIncludesPseudoMachineParser.input_stream).to eq("fetcher")
  end

  it "prepares JSONL checkpoint output before running" do
    expect(ModuleThatIncludesPseudoMachineParser).to receive(:prepare_output_for_stage!)
    allow(ModuleThatIncludesPseudoMachineParser).to receive(:jsonl_records_written).and_return(0)
    allow(ModuleThatIncludesPseudoMachineParser).to receive(:input_data)
    ModuleThatIncludesPseudoMachineParser.run
  end
end
