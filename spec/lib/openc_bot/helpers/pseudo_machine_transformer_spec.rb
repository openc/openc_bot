# frozen_string_literal: true

require "spec_helper"
require "openc_bot"
require "openc_bot/helpers/pseudo_machine_transformer"
# require "openc_bot/helpers/incremental_search"

module ModuleThatIncludesPseudoMachineTransformer
  extend OpencBot
  extend OpencBot::Helpers::PseudoMachineTransformer
end

describe OpencBot::Helpers::PseudoMachineTransformer
context "when a module that includes PseudoMachineTransformer" do
  it "has #run method" do
    expect(ModuleThatIncludesPseudoMachineTransformer).to respond_to(:run)
  end

  it "includes PersistenceHandler methods" do
    expect(ModuleThatIncludesPseudoMachineTransformer).to respond_to(:persist)
  end

  it "includes RegisterMethods methods" do
    expect(ModuleThatIncludesPseudoMachineTransformer).to respond_to(:validate_datum)
  end

  it "return's parser" do
    expect(ModuleThatIncludesPseudoMachineTransformer.input_stream).to eq("parser")
  end
end
