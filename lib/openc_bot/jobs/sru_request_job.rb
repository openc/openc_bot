# frozen_string_literal: true

# Resque worker class for processing single record update requests
class SruRequestJob
  def self.perform(params)
    bot_name = get_bot_name
    require_relative File.join(Dir.pwd, "lib", bot_name)
    runner = callable_from_file_name(bot_name)
    jurisdiction_code = runner.inferred_jurisdiction_code
    queue = ENV["QUEUE"]
    expected_queue_name = "sru_request_#{jurisdiction_code}"
    raise("Queue name '#{queue}' does not match the runner class '#{runner}'. Expected queue name '#{expected_queue_name}'") unless queue == expected_queue_name

    company_number = params["company_number"]

    output_json =
      begin
        runner.update_datum(company_number, false).to_json
      rescue Exception => e
        Resque.logger.info "Error in single record update: #{e}, #{e.message} (Returning error details in json)"
        { "error" => { "klass" => e.class.to_s, "message" => e.message, "backtrace" => e.backtrace } }.to_json
      end

    Resque.logger.info "Sending response SingleRecordUpdateJob : #{output_json.truncate(500)}"
    SingleRecordUpdateJob.enqueue(
      jurisdiction_code: jurisdiction_code,
      company_number: company_number,
      output: output_json,
    )
  end
end
