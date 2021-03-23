# frozen_string_literal: true

require "spec_helper"
require "openc_bot"
require "openc_bot/helpers/persistence_handler"

module ModuleThatIncludesPersistenceHandlerFoo
  extend OpencBot
  extend OpencBot::Helpers::PersistenceHandler
end

describe OpencBot::Helpers::PersistenceHandler do
  context "when a module that includes PersistenceHandler" do
    it "return's last word of module name" do
      expect(ModuleThatIncludesPersistenceHandlerFoo.output_stream).to eq("foo")
    end
  end
end
