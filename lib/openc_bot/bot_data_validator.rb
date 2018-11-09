module OpencBot
  module BotDataValidator
    module_function

    def validate(datum)
      datum.is_a?(Hash) &&
        !datum[:company][:name].nil? &&
        !datum[:company][:name].strip.empty? &&
        !datum[:source_url].strip.empty? &&
        !datum[:data].empty? &&
        datum[:data].all? { |data| !data[:data_type].to_s.strip.empty? && !data[:properties].empty? }
    rescue Exception => e
      # any probs then it's invalid
      false
    end
  end
end
