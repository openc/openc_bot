# encoding: UTF-8
module OpencBot
  module Helpers
    module Text
      extend self

      def normalise_utf8_spaces(raw_text)
        raw_text&&raw_text.gsub(/\xC2\xA0/, ' ')
      end

      def strip_all_spaces(text)
        text&&normalise_utf8_spaces(text).strip.gsub(/\s+/,' ')
      end


    end
  end
end
