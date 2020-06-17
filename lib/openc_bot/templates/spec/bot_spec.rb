# frozen_string_literal: true

require_relative "spec_helper"
require_relative "../lib/my_module"

describe MyModule do
  it "extends with OpencBot methods" do
    described_class.should respond_to :save_data
  end
end
