# frozen_string_literal: true

require 'luca_support/config'
require 'luca_record/dict'
require 'date'
require 'pathname'

module LucaBook
  class Dict < LucaRecord::Dict
    def self.latest_balance
      dict_dir = Pathname(LucaSupport::Config::Pjdir) / 'data' / 'balance'
      # TODO: search latest balance dictionary
      load_tsv_dict(dict_dir / 'start.tsv')
    end

    def self.issue_date(obj)
      Date.parse(obj.dig('_date', :label))
    end
  end
end
