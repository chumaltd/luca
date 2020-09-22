# frozen_string_literal: true
require 'luca_record/version'
require 'luca'
require 'luca_record/io'

module LucaRecord
  class Base
    include LucaRecord::IO
  end
end
