# frozen_string_literal: true

require "spec_helper"
require "openc_bot"
require "openc_bot/helpers/persistence_handler"
require "openc_bot/helpers/pseudo_machine_parser"
require "openc_bot/helpers/pseudo_machine_transformer"
require "fileutils"
require "json"
require "tmpdir"

module ModuleThatIncludesPersistenceHandlerFoo
  extend OpencBot
  extend OpencBot::Helpers::PersistenceHandler
end

module CheckpointTestParser
  extend OpencBot
  extend OpencBot::Helpers::PseudoMachineParser

  def self.parse(fetched_datum)
    fetched_datum
  end

  def self.track_company_processed; end
end

module CheckpointTestTransformer
  extend OpencBot::Helpers::PseudoMachineTransformer

  def self.encapsulate_as_per_schema(parsed_datum)
    parsed_datum
  end

  def self.validate_datum(_datum)
    []
  end

  def self.save_entity(_datum); end

  def self.track_company_processed; end
end

module CheckpointTestFetcher
  extend OpencBot
  extend OpencBot::Helpers::PersistenceHandler

  def self.track_company_processed; end
end

describe OpencBot::Helpers::PersistenceHandler do
  context "when a module that includes PersistenceHandler" do
    it "return's last word of module name" do
      expect(ModuleThatIncludesPersistenceHandlerFoo.output_stream).to eq("foo")
    end
  end

  describe "JSONL checkpoint/resume" do
    let(:acq_dir) { File.join(@tmp, "acq") }

    before do
      @tmp = Dir.mktmpdir("jsonl_checkpoint_")
      FileUtils.mkdir_p(acq_dir)
      ENV["ACQUISITION_DIRECTORY"] = acq_dir
      ENV["CHECKPOINT_EVERY"] = "2"
      ENV.delete("OPENC_BOT_JSONL_CHECKPOINT")
      [CheckpointTestParser, CheckpointTestTransformer, CheckpointTestFetcher].each do |mod|
        mod.finalize_output_stream! if mod.respond_to?(:finalize_output_stream!)
      end
    end

    after do
      [CheckpointTestParser, CheckpointTestTransformer, CheckpointTestFetcher].each do |mod|
        mod.finalize_output_stream! if mod.respond_to?(:finalize_output_stream!)
      end
      FileUtils.remove_entry(@tmp) if @tmp && File.exist?(@tmp)
      ENV.delete("ACQUISITION_DIRECTORY")
      ENV.delete("CHECKPOINT_EVERY")
      ENV.delete("OPENC_BOT_JSONL_CHECKPOINT")
      ENV.delete("NO_SAVE_DATA_IN_SQLITE")
    end

    def write_jsonl(path, records)
      File.write(path, records.map { |r| "#{r.to_json}\n" }.join)
    end

    def read_jsonl(path)
      File.readlines(path).map { |line| JSON.parse(line) }
    end

    def parser_input(records)
      write_jsonl(File.join(acq_dir, "fetcher.jsonl"), records)
    end

    def transformer_input(records)
      write_jsonl(File.join(acq_dir, "parser.jsonl"), records)
    end

    def simulate_crash(mod)
      io = mod.instance_variable_get(:@jsonl_partial_io)
      io&.close
      mod.instance_variable_set(:@jsonl_partial_io, nil)
      mod.instance_variable_set(:@jsonl_output_prepared, false)
    end

    it "writes parser output to a partial file and finalizes to jsonl" do
      parser_input([{ "n" => 1 }, { "n" => 2 }])
      CheckpointTestParser.run
      expect(File.exist?(File.join(acq_dir, "parser.jsonl.partial"))).to eq(true)
      expect(File.exist?(File.join(acq_dir, "parser.jsonl"))).to eq(false)

      CheckpointTestParser.finalize_output_stream!
      expect(File.exist?(File.join(acq_dir, "parser.jsonl.partial"))).to eq(false)
      expect(read_jsonl(File.join(acq_dir, "parser.jsonl"))).to eq([{ "n" => 1 }, { "n" => 2 }])
      expect(File.exist?(File.join(acq_dir, "parser.jsonl.checkpoint.json"))).to eq(false)
    end

    it "resumes a parser from a checkpoint without duplicating or dropping records" do
      parser_input([{ "n" => 1 }, { "n" => 2 }, { "n" => 3 }, { "n" => 4 }])
      CheckpointTestParser.run
      CheckpointTestParser.finalize_output_stream!
      expected = read_jsonl(File.join(acq_dir, "parser.jsonl"))

      File.delete(File.join(acq_dir, "parser.jsonl"))
      partial = File.join(acq_dir, "parser.jsonl.partial")
      first_two = expected[0..1]
      File.write(partial, first_two.map { |r| "#{r.to_json}\n" }.join)
      File.write(File.join(acq_dir, "parser.jsonl.checkpoint.json"), {
        "input_lines" => 2,
        "input_bytes" => File.foreach(File.join(acq_dir, "fetcher.jsonl")).first(2).join.bytesize,
        "bytes" => File.size(partial),
        "count" => 2
      }.to_json)

      CheckpointTestParser.run
      CheckpointTestParser.finalize_output_stream!

      resumed = read_jsonl(File.join(acq_dir, "parser.jsonl"))
      expect(resumed).to eq(expected)
      expect(resumed.uniq).to eq(resumed)
    end

    it "truncates un-checkpointed tail so a crash mid-window does not duplicate" do
      parser_input([{ "n" => 1 }, { "n" => 2 }, { "n" => 3 }])

      original_parse = CheckpointTestParser.method(:parse)
      CheckpointTestParser.define_singleton_method(:parse) do |fetched_datum|
        raise "simulated crash" if fetched_datum["n"] == 3

        fetched_datum
      end

      expect { CheckpointTestParser.run }.to raise_error("simulated crash")
      simulate_crash(CheckpointTestParser)

      CheckpointTestParser.define_singleton_method(:parse, original_parse)
      CheckpointTestParser.run
      CheckpointTestParser.finalize_output_stream!

      expect(read_jsonl(File.join(acq_dir, "parser.jsonl"))).to eq([{ "n" => 1 }, { "n" => 2 }, { "n" => 3 }])
    ensure
      CheckpointTestParser.define_singleton_method(:parse) { |fetched_datum| fetched_datum }
    end

    it "discards a legacy incomplete final jsonl when there is no valid checkpoint" do
      parser_input([{ "n" => 1 }, { "n" => 2 }])
      write_jsonl(File.join(acq_dir, "parser.jsonl"), [{ "n" => 1 }])

      CheckpointTestParser.run
      CheckpointTestParser.finalize_output_stream!

      expect(read_jsonl(File.join(acq_dir, "parser.jsonl"))).to eq([{ "n" => 1 }, { "n" => 2 }])
    end

    it "resumes a transformer from a checkpoint without duplicating or dropping records" do
      ENV["NO_SAVE_DATA_IN_SQLITE"] = "true"
      transformer_input([{ "n" => 1 }, { "n" => 2 }, { "n" => 3 }])
      CheckpointTestTransformer.run
      CheckpointTestTransformer.finalize_output_stream!
      expected = read_jsonl(File.join(acq_dir, "transformer.jsonl"))

      File.delete(File.join(acq_dir, "transformer.jsonl"))
      partial = File.join(acq_dir, "transformer.jsonl.partial")
      File.write(partial, "#{expected.first.to_json}\n")
      File.write(File.join(acq_dir, "transformer.jsonl.checkpoint.json"), {
        "input_lines" => 1,
        "input_bytes" => File.foreach(File.join(acq_dir, "parser.jsonl")).first.bytesize,
        "bytes" => File.size(partial),
        "count" => 1
      }.to_json)

      CheckpointTestTransformer.run
      CheckpointTestTransformer.finalize_output_stream!

      resumed = read_jsonl(File.join(acq_dir, "transformer.jsonl"))
      expect(resumed).to eq(expected)
      expect(resumed.uniq).to eq(resumed)
    end

    it "appends to the final jsonl when OPENC_BOT_JSONL_CHECKPOINT=0" do
      ENV["OPENC_BOT_JSONL_CHECKPOINT"] = "0"
      parser_input([{ "n" => 1 }])
      CheckpointTestParser.run

      expect(File.exist?(File.join(acq_dir, "parser.jsonl.partial"))).to eq(false)
      expect(read_jsonl(File.join(acq_dir, "parser.jsonl"))).to eq([{ "n" => 1 }])
    end

    it "does not checkpoint fetcher output" do
      CheckpointTestFetcher.persist({ "n" => 1 })
      expect(File.exist?(File.join(acq_dir, "fetcher.jsonl.partial"))).to eq(false)
      expect(read_jsonl(File.join(acq_dir, "fetcher.jsonl"))).to eq([{ "n" => 1 }])
    end

    it "counts records from the partial file while a stage is in progress" do
      parser_input([{ "n" => 1 }, { "n" => 2 }])
      CheckpointTestParser.run
      expect(CheckpointTestParser.records_processed).to eq(2)
      CheckpointTestParser.finalize_output_stream!
      expect(CheckpointTestParser.records_processed).to eq(2)
    end
  end
end
