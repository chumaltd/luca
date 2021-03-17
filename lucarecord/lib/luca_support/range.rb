# frozen_string_literal: true

module LucaSupport # :nodoc:
  # Partial range operation
  #
  module Range
    def self.included(klass) # :nodoc:
      klass.extend ClassMethods
    end

    def by_month(step = nil, from: nil, to: nil)
      return enum_for(:by_month, step, from: from, to: to) unless block_given?

      from ||= @start_date
      to ||= @end_date
      self.class.term_by_month(from, to, step || 1).each do |date|
        @cursor_start = date
        @cursor_end = step.nil? ? date : [date.next_month(step - 1), to].min
        yield @cursor_start, @cursor_end
      end
    end

    module ClassMethods
      def term_by_month(start_date, end_date, step = 1)
        Enumerator.new do |yielder|
          each_month = start_date
          while each_month <= end_date
            yielder << each_month
            each_month = each_month.next_month(step)
          end
        end
      end
    end
  end
end
