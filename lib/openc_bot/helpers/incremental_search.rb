# encoding: UTF-8
module IncrementalSearch

  def datum_exists?(uid)
    # TODO: Remove hard-coded references to table name and uid field name (i.e. company_number)
    !!select("ocdata.company_number FROM ocdata WHERE company_number = '?' LIMIT 1", uid).first
  end

  # Gets new records using an incremental search
  def get_new(options={})
    return unless old_highest_numbers = options.delete(:highest_entry_uids) || highest_entry_uids
    # offset by rewind count if set and also in that case assume by default we want to skip_existing_companies
    options = {:offset => (0 - incremental_rewind_count), :skip_existing_entries => true}.merge(options) if incremental_rewind_count
    new_highest_numbers = old_highest_numbers.collect do |old_highest_number|
      incremental_search(old_highest_number, options)
    end
    save_var(:highest_entry_uids, new_highest_numbers)
  end

  def highest_entry_uids(force_get = false)
    bad_results = []
    results = get_var('highest_entry_uids')
    if results.nil? || results.empty? || (results.is_a?(Array) && results.any?{ |r| r.nil? || r.empty? })
      results = entity_uid_prefixes.collect do |prefix|
        hcn = highest_entry_uid_result(:prefix => prefix)
        bad_results << prefix if (hcn.nil? || hcn.empty?)
        hcn
      end
    end
    results.compact! unless bad_results.empty?
    return results unless results.empty?
  end

  def highest_entry_uid_result(options={})
    if options[:prefix]
      sql_query = ["ocdata.company_number FROM ocdata WHERE company_number LIKE ? ORDER BY cast(substr(company_number,?) as real) DESC LIMIT 1", ["#{options[:prefix]}%", options[:prefix].length + 1]]
    else
      sql_query = "ocdata.company_number FROM ocdata ORDER BY cast(company_number as real) DESC LIMIT 1"
    end
    select(*sql_query).first['company_number']# rescue nil
  rescue SqliteMagic::NoSuchTable
    # first run, so no table or database yet
    return "#{options[:prefix]}0"
  end


  def incremental_rewind_count
    self.const_defined?('INCREMENTAL_REWIND_COUNT') ? self.const_get('INCREMENTAL_REWIND_COUNT') : nil
  end

  def entity_uid_prefixes
    self.const_defined?('ENTITY_UID_PREFIXES') ? self.const_get('ENTITY_UID_PREFIXES') : [nil]
  end

  def incremental_search(uid, options={})
    first_number = uid.dup
    current_number = nil # set up ouside of loop
    error_count = 0
    last_good_co_no = nil
    skip_existing_entries = options.delete(:skip_existing_entries)
    # start at given number but offset by given amount. i.e. by offset
    uid = increment_number(uid, options[:offset]) if options[:offset]
    loop do
      current_number = uid
      if skip_existing_entries and datum_exists?(uid)
        uid = increment_number(uid)
        error_count = 0 # reset error count
        next
      elsif update_datum(current_number, false)
        last_good_co_no = current_number
        error_count = 0 # reset error count
      else
        error_count += 1
        puts "Failed to find company with uid #{current_number}. Error count: #{error_count}" if verbose?
        break if error_count > max_failed_count
      end
      uid = increment_number(uid)
    end
    # return orig uid if we haven't had any new entities
    last_good_co_no ? last_good_co_no.to_s : first_number
  end

  def increment_number(uid,increment_amount=1)
    orig_uid = uid.to_s.dup
    uid.to_s.sub(/\d+/) do |d|
      length = d.length
      incremented_number = d.to_i + increment_amount
      length = d.length
      length = incremented_number.to_s.length if increment_amount < 0 and not d[/^0/]
      sprintf("%0#{length}d", incremented_number)
    end
  end

  def max_failed_count
    self.const_defined?('MAX_FAILED_COUNT') ? self.const_get('MAX_FAILED_COUNT') : 10
  end

  def stale_entry_uids(stale_count=nil)
    # TODO: refine this query so company_number field_name, stale date, default stale count are not hard-coded
    stale_count ||= 1000
    sql_query = "ocdata.* from ocdata WHERE retrieved_at IS NULL OR strftime('%s', retrieved_at) < strftime('%s',  '#{Date.today - 30}') LIMIT #{stale_count.to_i}"
    raw_data = select(sql_query).each do |res|
      yield res['company_number']
    end
  end

  def update_data
    get_new
    update_stale
    save_run_report(:status => 'success')
  end

  # This method updates a datum given by a uid (e.g. a company_number), by fetching new data, processing it
  # and then saving it. It assumes the methods for doing this (#fetch_datum and #process_datum) are implemented
  # in the module that includes this method.
  #
  # If no second argument is passed to this method, or false is passed, the method will return the processed data hash
  # If true is passed as the second argument, the method will output the updated result as json to STDOUT, which can
  # then be consumed by, say, something which triggered this method, for example if it was called by a rake task
  # which in turn might have been called by the main OpenCorporates application
  def update_datum(uid, output_as_json=false)
    return unless json_data = fetch_datum(uid)
    processed_data = process_datum(json_data).merge(:retrieved_at => Time.now.to_s)
    # prepare the data for saving (converting Arrays, Hashes to json) and save the original json too
    # as we're not extracting everything from it yet
    data_to_be_saved = prepare_for_saving(processed_data).merge(:data => json_data)
    # TODO: Remove hard-coded reference to company_number
    save_data([:company_number], data_to_be_saved)
    if output_as_json
      puts processed_data.to_json
    else
      processed_data
    end
  rescue Exception => e
    output_json_error_message(e) if output_as_json
  end

  def update_stale(stale_count=nil)
    stale_entry_uids(stale_count) do |stale_entry_uid|
      update_datum(stale_entry_uid)
    end
  end

  private
  # This is a utility method for outputting an error message as json to STDOUT
  # (which can then be handled by the importer)
  def output_json_error_message(err_obj)
    err_msg = {'error' => {'klass' => err_obj.class.to_s, 'message' => err_obj.message, 'backtrace' => err_obj.backtrace}}
    puts err_msg.to_json
  end

  def prepare_for_saving(raw_data_hash)
    # deep clone hash
    prepared_data = Marshal.load( Marshal.dump(raw_data_hash) )
    #This jsonifies each value that is an an array or hash so that it can be saved as a string in sqlite
    prepared_data.each do |k,v|
      case v
      when Array, Hash
        prepared_data[k] = v.to_json
      end
    end
    prepared_data
  end

end