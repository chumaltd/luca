# frozen_string_literal: true

module LucaSalary
  module Accumulator
    def self.included(klass) #:nodoc:
      klass.extend ClassMethods
    end

    module ClassMethods
      def accumulate(records)
        count = 0
        result = records.each_with_object({}) do |record, result|
          count += 1
          record
            .select { |k, _v| /^[1-4][0-9A-Fa-f]{,3}$/.match(k) }
            .each do |k, v|
            next if v.nil?

            result[k] = result[k] ? result[k] + v : v
          end
        end
        [result, count]
      end
    end
  end
end
