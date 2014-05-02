# encoding: UTF-8
require_relative '../../../spec_helper'
require 'openc_bot'
require 'openc_bot/incrementers'

describe OpencBot::ManualIncrementer do
  before do
    @app_path = File.expand_path(File.join(File.dirname(__FILE__), "../../.."))
    @incrementer = OpencBot::ManualIncrementer.new(:manual_incrementer, :fields => [:url], :app_path => @app_path, :show_progress => false)
    @incrementer.sqlite_magic_connection.execute("DELETE FROM items")
    @incrementer.reset_current
  end
  
  after do
    @incrementer.sqlite_magic_connection.execute("DROP TABLE items")
  end

  it "should return same stuff as saved, plus an id" do
    hashes = [
      {"name" => "tony", "address" => "number 0", "url" => "http://example.com/tony"},
      {"name" => "jude", "address" => "number 1", "url" => "http://example.com/jude"},
      {"name" => "brig", "address" => "number 2", "url" => "http://example.com/brig"}
    ]
    hashes.each do |h|
      @incrementer.add_row(h)
    end
    @incrementer.enum.each.with_index(1) do |row, i|
      # id assignment in sqlite is 1 indexed, not 0
      row.should == hashes[i - 1].merge("_id" => i)
    end
  end

  it "should resume from where left off" do
    hashes = [
              {"name" => "tony", "address" => "number 1", "url" => "http://example.com/tony"},
              {"name" => "jude", "address" => "number 2", "url" => "http://example.com/jude"},
              {"name" => "brig", "address" => "number 3", "url" => "http://example.com/brig"}
             ]
    hashes.each do |h|
      @incrementer.add_row(h)
    end
    counter = @incrementer.enum
    counter.next.should == hashes[0].merge("_id" => 1)
    counter.next.should == hashes[1].merge("_id" => 2)

    @new_incrementer = OpencBot::ManualIncrementer.new(:manual_incrementer, :app_path => @app_path, :fields => [:url])
    # TODO: effectively performs id >= current_row['_id'] which results
    # in the same row being run twice across the two separate runs.
    # Is this desired behaviour?
    @new_incrementer.resumable.next.should == hashes[1].merge("_id" => 2)
  end

  it "should be relatively fast to save" do
    hashes = []
    (0...2000).each do |n|
      hashes << {'number' => n}
    end
    hashes.each do |h|
      @incrementer.add_row(h)
    end
  end

  it "should be relatively fast to skip" do
    hashes = []
    (0...2000).each do |n|
      hashes << {'number' => n}
    end
    hashes.each do |h|
      @incrementer.add_row(h)
    end
    counter = @incrementer.enum
    start_time = Time.now
    1000.times do
      counter.next
    end
    end_time = Time.now
    @new_incrementer = OpencBot::ManualIncrementer.new(:manual_incrementer, :app_path => @app_path, :fields => [:url])
    # TODO: effectively performs id >= current_row['_id'] which results
    # in the same row being run twice across the two separate runs.
    # Is this desired behaviour?
    @new_incrementer.resumable.next["number"].should == 999
  end
end
