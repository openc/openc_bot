# encoding: UTF-8
module OpencBot
  module Helpers
    module Dates
      extend self

      def normalise_utf8_spaces(raw_text)
        raw_text&&raw_text.gsub(/\xC2\xA0/, ' ')
      end

    end
  end
end
