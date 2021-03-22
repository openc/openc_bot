# frozen_string_literal: true

require "spec_helper"
require "openc_bot"
require "openc_bot/helpers/persistence_handler"
# require "openc_bot/helpers/incremental_search"

module ModuleThatIncludesPersistenceHandlerFoo
  extend OpencBot
  extend OpencBot::Helpers::PersistenceHandler
end

describe "a module that includes PersistenceHandler" do
  before do
  end

  after do
    # remove_test_database
  end

  describe "output_stream" do
    it "should return last word of module name" do
      expect(ModuleThatIncludesPersistenceHandlerFoo.output_stream).to eq("foo")
    end
  end

end
