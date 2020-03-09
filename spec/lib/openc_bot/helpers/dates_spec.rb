require "spec_helper"
require "openc_bot/helpers/dates"

describe OpencBot::Helpers::Dates do
  describe "#normalise_us_date" do
    it "returns nil if blank" do
      expect(described_class.normalise_us_date(nil)).to be_nil
      expect(described_class.normalise_us_date("")).to be_nil
    end

    it "converts date to string" do
      date = Date.today
      expect(described_class.normalise_us_date(date)).to eq(date.to_s)
    end

    it "converts US date if in slash format" do
      expect(described_class.normalise_us_date("01/04/2006").to_s).to eq("2006-01-04")
    end

    it "converts two digit year" do
      expect(described_class.normalise_us_date("23-Aug-10").to_s).to eq("2010-08-23")
      expect(described_class.normalise_us_date("23-Aug-98").to_s).to eq("1998-08-23")
      expect(described_class.normalise_us_date("05/Oct/10").to_s).to eq("2010-10-05")
      expect(described_class.normalise_us_date("05/10/10").to_s).to eq("2010-05-10")
      expect(described_class.normalise_us_date("5/6/10").to_s).to eq("2010-05-06")
      expect(described_class.normalise_us_date("5/6/31").to_s).to eq("1931-05-06")
    end

    it "does not convert date if not in slash format" do
      expect(described_class.normalise_us_date("2006-01-04").to_s).to eq("2006-01-04")
    end
  end

  describe "when normalising uk date" do
    it "returns nil if blank" do
      expect(described_class.normalise_uk_date(nil)).to be_nil
      expect(described_class.normalise_uk_date("")).to be_nil
    end

    it "converts date to string" do
      date = Date.today - 30
      expect(described_class.normalise_uk_date(date)).to eq(date.to_s)
    end

    it "converts UK date if in slash format" do
      expect(described_class.normalise_uk_date("01/04/2006").to_s).to eq("2006-04-01")
    end

    it "converts UK date if in dot format" do
      expect(described_class.normalise_uk_date("01.04.2006").to_s).to eq("2006-04-01")
    end

    it "converts two digit year" do
      expect(described_class.normalise_uk_date("23-Aug-10").to_s).to eq("2010-08-23")
      expect(described_class.normalise_uk_date("23-Aug-98").to_s).to eq("1998-08-23")
      expect(described_class.normalise_uk_date("05/Oct/10").to_s).to eq("2010-10-05")
      expect(described_class.normalise_uk_date("05/10/10").to_s).to eq("2010-10-05")
    end

    it "does not convert date if not in slash format" do
      expect(described_class.normalise_uk_date("2006-01-04").to_s).to eq("2006-01-04")
    end
  end
end
