# frozen_string_literal: true

require 'luca_support/config'
require 'luca_record/dict'

module LucaBook
  class Dict < LucaRecord::Dict

    @filename = 'dict.tsv'

    Data = load
  end
end
