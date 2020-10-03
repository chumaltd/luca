# frozen_string_literal: true

require 'luca_record/version'
require 'luca_record/io'
require 'luca_support'

module LucaRecord
  class Base
    include LucaRecord::IO
    include LucaSupport::View
  end
end
