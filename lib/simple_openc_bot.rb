require 'active_support/core_ext'

module SimpleOpencBot
  extend OpencBot

#  def export_data
#    sql_query = "ocdata.* from ocdata where seen_recently = 'yes'"
#    select(sql_query).map do |record|
#      company_record = Company.new(record)
#      hash = prepare_for_export(company_record)
#
#      last_retrieved_at = record[:retrieved_at]
#
#      if DateTime.strptime(last_retrieved_at, '%Y-%m-%dT%H:%M:%S') < Time.now - 30.days
#        hash[:end_date] = Time.now
#        hash[:end_date_type] = 'before'
#        record[:seen_recently] = 'no'
#        save([record])
#      else
#        hash[:sample_date] = last_retrieved_at
#      end
#
#      hash
#    end
#  end
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
    class_attribute :_fields, :_unique_fields

    def self.fields(*fields)
      self._fields = fields
      fields.each do |field|
        define_method(field) do
          instance_variable_get("@#{field}")
        end

        define_method("#{field}=") do |value|
          instance_variable_set("@#{field}", value)
        end
      end
    end

    def self.unique_fields(*fields)
      self._unique_fields = fields
    end

    def initialize(attrs)
      attrs.each do |k, v|
        send("#{k}=", v)
      end
    end
  end
end
