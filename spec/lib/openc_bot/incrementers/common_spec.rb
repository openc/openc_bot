# frozen_string_literal: true

require_relative "../../../spec_helper"
require "openc_bot"
require "openc_bot/incrementers"

describe OpencBot::ManualIncrementer do
  before do
    @app_path = File.expand_path(File.join(File.dirname(__FILE__), "../../.."))
    @incrementer = described_class.new(:manual_incrementer, fields: [:url], app_path: @app_path, show_progress: false)
    @incrementer.sqlite_magic_connection.execute("DELETE FROM items")
    @incrementer.reset_current
  end

  after do
    @incrementer.sqlite_magic_connection.execute("DROP TABLE items")
  end

  it "returns same stuff as saved, plus an id" do
    hashes = [
      { "name" => "tony", "address" => "number 0", "url" => "http://example.com/tony" },
      { "name" => "jude", "address" => "number 1", "url" => "http://example.com/jude" },
      { "name" => "brig", "address" => "number 2", "url" => "http://example.com/brig" },
    ]
    hashes.each do |h|
      @incrementer.add_row(h)
    end
    @incrementer.enum.each.with_index(1) do |row, i|
      # id assignment in sqlite is 1 indexed, not 0
      expect(row).to eq(hashes[i - 1].merge("_id" => i))
    end
  end

  it "resumes from where left off" do
    hashes = [
      { "name" => "tony", "address" => "number 1", "url" => "http://example.com/tony" },
      { "name" => "jude", "address" => "number 2", "url" => "http://example.com/jude" },
      { "name" => "brig", "address" => "number 3", "url" => "http://example.com/brig" },
    ]
    hashes.each do |h|
      @incrementer.add_row(h)
    end
    counter = @incrementer.enum
    expect(counter.next).to eq(hashes[0].merge("_id" => 1))
    expect(counter.next).to eq(hashes[1].merge("_id" => 2))

    @new_incrementer = described_class.new(:manual_incrementer, app_path: @app_path, fields: [:url])
    # TODO: effectively performs id >= current_row['_id'] which results
    # in the same row being run twice across the two separate runs.
    # Is this desired behaviour?
    expect(@new_incrementer.resumable.next).to eq(hashes[1].merge("_id" => 2))
  end

  it "is relatively fast to save" do
    hashes = []
    (0...2000).each do |n|
      hashes << { "number" => n }
    end
    hashes.each do |h|
      @incrementer.add_row(h)
    end
  end

  it "is relatively fast to skip" do
    hashes = []
    (0...2000).each do |n|
      hashes << { "number" => n }
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
    @new_incrementer = described_class.new(:manual_incrementer, app_path: @app_path, fields: [:url])
    # TODO: effectively performs id >= current_row['_id'] which results
    # in the same row being run twice across the two separate runs.
    # Is this desired behaviour?
    expect(@new_incrementer.resumable.next["number"]).to eq(999)
  end
end
