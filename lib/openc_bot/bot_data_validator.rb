module OpencBot
  module BotDataValidator

    extend self
    def validate(datum)
      datum.kind_of?(Hash) and
      datum[:company][:name] and
      not datum[:company][:name].strip.empty? and
      not datum[:source_url].strip.empty? and
      not datum[:data].empty? and
      datum[:data].all?{ |data| not data[:data_type].to_s.strip.empty? and not data[:properties].empty? }
    rescue Exception => e
      #any probs then it's invalid
      false
    end
  end
end
