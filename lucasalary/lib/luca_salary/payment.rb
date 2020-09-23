require 'date'
require 'pathname'
require 'json'
require 'mail'
require 'yaml'
require 'luca'
require 'luca_salary'
require 'luca_record'

module LucaSalary
  class Payment < LucaRecord::Base

    @dirname = 'payments'

  end
end
