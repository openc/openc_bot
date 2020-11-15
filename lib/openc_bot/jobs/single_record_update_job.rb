# frozen_string_literal: true

# Stub resque worker class for sending results of a single record update to openc
class SingleRecordUpdateJob
  @queue = :single_record_update

  def self.enqueue(
    jurisdiction_code:,
    company_number:,
    output:
  )
    Resque.enqueue(
      self,
      jurisdiction_code: jurisdiction_code,
      company_number: company_number,
      output: output,
      returning_at: Time.now.utc,
    )
  end
end
