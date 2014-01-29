# encoding: UTF-8
require_relative '../../spec_helper'
require 'openc_bot/helpers/dates'

describe OpencBot::Helpers::Dates do
  describe "#normalise_us_date" do
    it "should return nil if blank" do
      OpencBot::Helpers::Dates.normalise_us_date(nil).should be_nil
      OpencBot::Helpers::Dates.normalise_us_date('').should be_nil
    end

    it "should convert date to string" do
      date = Date.today
      OpencBot::Helpers::Dates.normalise_us_date(date).should == date.to_s
    end

    it "should convert US date if in slash format" do
      OpencBot::Helpers::Dates.normalise_us_date('01/04/2006').to_s.should == '2006-01-04'
    end

    it "should convert two digit year " do
      OpencBot::Helpers::Dates.normalise_us_date('23-Aug-10').to_s.should == '2010-08-23'
      OpencBot::Helpers::Dates.normalise_us_date('23-Aug-98').to_s.should == '1998-08-23'
      OpencBot::Helpers::Dates.normalise_us_date('05/Oct/10').to_s.should == '2010-10-05'
      OpencBot::Helpers::Dates.normalise_us_date('05/10/10').to_s.should == '2010-05-10'
      OpencBot::Helpers::Dates.normalise_us_date('5/6/10').to_s.should == '2010-05-06'
      OpencBot::Helpers::Dates.normalise_us_date('5/6/31').to_s.should == '1931-05-06'
    end

    it "should not convert date if not in slash format" do
      OpencBot::Helpers::Dates.normalise_us_date('2006-01-04').to_s.should == '2006-01-04'
    end
  end

  describe "when normalising uk date" do
    it "should return nil if blank" do
      OpencBot::Helpers::Dates.normalise_uk_date(nil).should be_nil
      OpencBot::Helpers::Dates.normalise_uk_date('').should be_nil
    end

    it "should convert date to string" do
      date = Date.today - 30
      OpencBot::Helpers::Dates.normalise_uk_date(date).should == date.to_s
    end

    it "should convert UK date if in slash format" do
      OpencBot::Helpers::Dates.normalise_uk_date('01/04/2006').to_s.should == '2006-04-01'
    end

    it "should convert UK date if in dot format" do
      OpencBot::Helpers::Dates.normalise_uk_date('01.04.2006').to_s.should == '2006-04-01'
    end

    it "should convert two digit year " do
      OpencBot::Helpers::Dates.normalise_uk_date('23-Aug-10').to_s.should == '2010-08-23'
      OpencBot::Helpers::Dates.normalise_uk_date('23-Aug-98').to_s.should == '1998-08-23'
      OpencBot::Helpers::Dates.normalise_uk_date('05/Oct/10').to_s.should == '2010-10-05'
      OpencBot::Helpers::Dates.normalise_uk_date('05/10/10').to_s.should == '2010-10-05'
    end

    it "should not convert date if not in slash format" do
      OpencBot::Helpers::Dates.normalise_uk_date('2006-01-04').to_s.should == '2006-01-04'
    end
  end
end