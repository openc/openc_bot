# encoding: UTF-8
require_relative '../../../spec_helper'
require 'openc_bot'
require 'openc_bot/incrementers/common'


describe OpencBot::ManualIncrementer do
  before do
    @app_path = File.expand_path(File.join(File.dirname(__FILE__), "../../.."))
    @incrementer = OpencBot::ManualIncrementer.new(:app_path => @app_path)
    @incrementer.reset_current
  end

  it "should return same stuff as saved, plus an id" do
    hashes = [
              {"name" => "tony", "address" => "number 1"},
              {"name" => "jude", "address" => "number 2"},
              {"name" => "brig", "address" => "number 3"}
             ]
    hashes.each do |h|
      @incrementer.save_hash(h)
    end
    @incrementer.enum.each_with_index do |row, i|
      row.should == hashes[i].merge("id" => i)
    end
  end

  it "should resume from where left off" do
    hashes = [
              {"name" => "tony", "address" => "number 1"},
              {"name" => "jude", "address" => "number 2"},
              {"name" => "brig", "address" => "number 3"}
             ]
    hashes.each do |h|
      @incrementer.save_hash(h)
    end
    counter = @incrementer.enum
    counter.next.should == hashes[0].merge("id" => 0)
    counter.next.should == hashes[1].merge("id" => 1)
    @new_incrementer = OpencBot::ManualIncrementer.new(:app_path => @app_path)
    puts @new_incrementer.read_current
    @new_incrementer.enum.next.should == hashes[1].merge("id" => 1)
  end

  it "should be relatively fast to save" do
    hashes = []
    (0...20000).each do |n|
      hashes << {'number' => n}
    end
    hashes.each do |h|
      @incrementer.save_hash(h)
    end
  end

  it "should be relatively fast to skip" do
    hashes = []
    (0...20000).each do |n|
      hashes << {'number' => n}
    end
    hashes.each do |h|
      @incrementer.save_hash(h)
    end
    counter = @incrementer.enum
    start = Time.now
    1000.times do
      counter.next
    end
    start = Time.now
    @new_incrementer = OpencBot::ManualIncrementer.new(:app_path => @app_path)
    @new_incrementer.enum.next["number"].should == 1000
  end
end
