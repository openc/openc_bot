# encoding: UTF-8
require 'simple_openc_bot'
require 'mechanize'

class BotWithSimpleIterator < SimpleOpencBot

  yields Object

  # This method should return an array of Records. It must be defined.
  def fetch_all_records(opts={})

    # The following methods illustrate four common incrementer
    # patterns.

    # If a run is interrupted, it will resume where it left off --
    # unless you pass the reset flag (`bundle exec openc_bot rake
    # bot:run -- --reset`), or a full iteration has previously
    # completed (in which case it will start again)

    # Try running `bundle exec openc_bot rake bot:run`, using CTRL-C
    # to interrupt, and then try resuming.

    increment_over_ascii(opts)
    increment_over_number(opts)
    increment_over_manual(opts)
    combine_incrementers(opts)
  end


  def increment_over_ascii(opts)
    # Create the incrementer
    ascii_incrementer =  OpencBot::AsciiIncrementer.new(
      :ascii_incrementer,
      opts.merge(:size => 2))

    ascii_incrementer.resumable.each do |letters|
      # This will iterate over all two-digit combinations of 0-9 and
      # a-z.
      puts "http://assets.opencorporates.com/test_bot_page_#{letters}.html"
    end
  end

  def increment_over_number(opts)
    # Create the incrementer
    numeric_incrementer = NumericIncrementer.new(
      :numeric_incrementer,
      opts.merge(
        :start_val => 0,
        :end_val => 20))

    numeric_incrementer.resumable.each do |number|
      # This will iterate over numbers 0 - 20
      puts "http://assets.opencorporates.com/test_bot_page_#{number}.html"
    end
  end

  def increment_over_manual(opts)
    # Create the incrementer
    manual_incrementer = OpencBot::ManualIncrementer.new(
      :manual_incrementer,
      opts.merge(:fields => [:name]))

    if !manual_incrementer.populated
      # Populate it, if it's not been done before
      manual_incrementer.add_row({"name" => "Bob"})
      manual_incrementer.add_row({"name" => "Sue"})
    end

    # Mark populating as complete.. the `populated` flag is not
    # necessary, but it's useful when debugging to skip slow
    # population steps.
    manual_incrementer.populated

    manual_incrementer.resumable.each do |row|
      # This will iterate over all the rows added previously.
      puts "http://assets.opencorporates.com/test_bot_page_#{row["name"]}.html"
    end
  end


  # Often you will need to use an iterator to build a list of pages to
  # get, using another iterator.
  def combine_incrementers(opts)
    ascii_incrementer =  OpencBot::AsciiIncrementer.new(
      :ascii_incrementer_2,
      opts.merge(:size => 1))

    manual_incrementer = OpencBot::ManualIncrementer.new(
      :manual_incrementer_2,
      opts.merge(:fields => [:url]))

    ascii_incrementer.resumable.each do |letters|
      get_urls_for_letter_combination(letters).each do |url|
        manual_incrementer.add_row({"url" => url})
      end
    end

    manual_incrementer.resumable.each do |row|
      puts row["url"]
    end

  end

  def get_urls_for_letter_combination(letters)
    # This method might do something like:
    # page = http_client.get("http://somewhere.com/?q=#{letters}")
    # urls = page.xpath("//a/@href")

    # However, for demonstration purposes, we just return:
    ["http://foo.com/#{letters}/1", "http://foo.com/#{letters}/2"]
  end
end
