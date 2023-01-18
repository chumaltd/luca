# frozen_string_literal: true

require 'luca_support'
require 'luca_record'

module LucaSalary
  class Total < LucaRecord::Base
    @dirname = 'payments/total'

    attr_reader :slips

    def initialize(year)
      @date = Date.new(year.to_i, 12, -1)
      @slips = Total.term(year, 1, year, 12).map do |slip, _path|
        slip['profile'] = parse_current(Profile.find(slip['profile_id']))
        slip
      end
      @dict = LucaRecord::Dict.load_tsv_dict(Pathname(LucaSupport::PJDIR) / 'dict' / 'code.tsv')
    end
  end
end
