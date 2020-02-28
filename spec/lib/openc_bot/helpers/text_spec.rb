require_relative "../../spec_helper"
require "openc_bot/helpers/text"

describe OpencBot::Helpers::Text do
  describe "#normalise_utf8_spaces" do
    it "converts UTF-8 spaces to normal spaces" do
      raw_and_normalised_text = {
        "Hello World" => "Hello World",
        "" => "",
        nil => nil,
        " \xC2\xA0\xC2\xA0 Mr Fred Flintstone  \xC2\xA0" => "    Mr Fred Flintstone   ",
        "AVTOPREVOZNIŠTVO - PREVOZ BLAGA ROBERT FLORJANČIČ S.P." => "AVTOPREVOZNIŠTVO - PREVOZ BLAGA ROBERT FLORJANČIČ S.P.",
      }
      raw_and_normalised_text.each do |raw_text, normalised_text|
        expect(described_class.normalise_utf8_spaces(raw_text)).to eq(normalised_text)
      end
    end
  end

  describe "#strip_all_spaces" do
    it "strips all spaces from text" do
      expect(described_class.strip_all_spaces(" \n \xC2\xA0\xC2\xA0 Mr Fred Flintstone\n  ")).to eq("Mr Fred Flintstone")
    end

    it "does not strip UTF8 chars that aren't spaces" do
      expect(described_class.strip_all_spaces("   \xC3\x8Dan Flintstone\n  ")).to eq("Ían Flintstone")
    end

    it "replaces UTF8 space with normal space" do
      expect(described_class.strip_all_spaces("   Mr\xC2\xA0Fred Flintstone\n  ")).to eq("Mr Fred Flintstone")
    end

    it "does not mess with other UTF8 characters" do
      utf8_name = "AVTOPREVOZNIŠTVO - PREVOZ BLAGA ROBERT FLORJANČIČ S.P."
      expect(described_class.strip_all_spaces(utf8_name)).to eq(utf8_name)
    end

    it "returns nil when nil given" do
      expect(described_class.strip_all_spaces(nil)).to be_nil
    end

    it "replaces multiple spaces with single space" do
      expect(described_class.strip_all_spaces("   Mr\xC2\xA0Fred  Percy Flintstone\n  ")).to eq("Mr Fred Percy Flintstone")
    end
  end
end
