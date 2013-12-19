require 'active_support/core_ext'
require 'openc_bot'

class SimpleOpencBot
  include OpencBot

  def update_data
    fetch_records.each do |record|
      save_data(record.class.unique_fields, record.to_hash)
    end
  end

  def all_stored_records
    sql_query = "ocdata.* from ocdata"
    select(sql_query).map { |record| record['_type'].constantize.new(record) }
  end

  def unexported_stored_records
    sql_query = "ocdata.* from ocdata"
    select(sql_query).map { |record| record['_type'].constantize.new(record) }
  end

  def export_data
    all_stored_records.each do |record|
      #record.mark_as_exported!

      save_data(record.class.unique_fields, record.to_hash)
      record.to_pipeline
    end
  end

  def prepare_for_export(raw_data)
    record = Hash[raw_data.map {|k, v| [k.to_sym, v]}]
    company = record[:name]
    licence_property = {
      data_type: :licence,
      properties: {
        category: 'Financial',
        jurisdiction_classification: [record[:type]],
      }
    }
    output = {
      sample_date: record[:retrieved_at],
      company: {
        name: company_name,
        jurisdiction: JURISDICTION,
      },
      source_url: UTAH_INSTITUTIONS_FILE_URL,
      data: [licence_property],
      sample_date: record[:sample_date],
      end_date: record[:end_date]
    }
    # XXX all the other dates
    # XXX mark as exported
    output
  end

  def validate
    # check all_records has been implemented, and returns a list of BaseLicenceRecords
    # check final output against JSON schema
  end


  # def export_data
  #   sql_query = "ocdata.* from ocdata where seen_recently = 'yes'"
  #   select(sql_query).map do |record|
  #     company_record = Company.new(record)
  #     hash = prepare_for_export(company_record)

  #     last_retrieved_at = record[:retrieved_at]

  #     if DateTime.strptime(last_retrieved_at, '%Y-%m-%dT%H:%M:%S') < Time.now - 30.days
  #       hash[:end_date] = Time.now
  #       hash[:end_date_type] = 'before'
  #       record[:seen_recently] = 'no'
  #       save([record])
  #     else
  #       hash[:sample_date] = last_retrieved_at
  #     end


  #     hash
  #   end
  # end
#
#  def update_data
#    records = all_records.each {|record| record[:seen_recently] = 'yes'}
#    save(records)
#    save_run_report(:status => 'success')
#  end
#
#  private
#  def save(records)
#    unique_keys = records.first.unique_keys
#    data = records.map {|record| Hash[record]}
#    save_data(unique_keys, data)
#  end
#
#  def prepare_for_export(record)
#    raise 'Implement in bot'
#  end
#
#  def all_records
#    raise 'Implement in bot'
#  end
#
#  def unique_keys
#    raise 'Implement in bot'
#  end


  class BaseLicenceRecord
    class_attribute :_store_fields, :_export_fields, :_unique_fields, :_type

    def self.store_fields(*fields)
      self._store_fields = fields
      fields << :last_exported_date
      fields.each do |field|
        attr_accessor field
      end
    end

    def self.unique_fields(*fields)
      self._unique_fields = fields unless fields.empty?
      self._unique_fields
    end

    def initialize(attrs)
      self._type = self.class.name
      attrs.each do |k, v|
        send("#{k}=", v)
      end
    end

    def to_hash
      hsh = Hash[_store_fields.map{|field| [field, send(field)]}]
      hsh[:_type] = self.class.name
      hsh
    end

    def mark_as_exported

    end

    def save
    end

  end
end
