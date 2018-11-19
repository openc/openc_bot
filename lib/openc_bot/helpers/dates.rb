require "date"
module OpencBot
  module Helpers
    module Dates
      module_function

      AMERICAN_DATE_RE = %r_\A\s*(\d{1,2})/(\d{1,2})/(\d{4}|\d{2})_.freeze

      def normalise_uk_date(raw_date)
        return if raw_date.nil? || raw_date.to_s.strip.empty?

        if raw_date.is_a?(String)
          cleaned_up_date = raw_date.gsub(/\s+/, "") =~ /^\d+\/[\d\w]+\/\d+$/ ? raw_date.tr("/", "-") : raw_date
          raw_date = to_date(cleaned_up_date.sub(/^(\d{1,2}-)([\w\d]+-)([01]\d)$/, '\1\220\3').sub(/^(\d{1,2}-)([\w\d]+-)([9]\d)$/, '\1\219\3'))
        end
        raw_date.to_s
      end

      def normalise_us_date(raw_date)
        return if raw_date.nil? || raw_date.to_s.strip.empty?

        # we want to set century to 19 if there's none set and the years are in the 20s or later
        raw_date = raw_date.to_s.sub(/^(\s*\d{1,2}[\/-]\d{1,2}[\/-])([2-9]\d)$/, '\119\2')
        iso_date = raw_date.to_s.sub(AMERICAN_DATE_RE) { |_m| "#{Regexp.last_match(3)}-#{Regexp.last_match(1)}-#{Regexp.last_match(2)}" }
        to_date(iso_date, true).to_s
      end

      def to_date(date, comp = false)
        return if date.nil?

        Date.parse(date, comp)
      end

      private_class_method :to_date
    end
  end
end
