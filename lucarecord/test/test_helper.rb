# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require 'luca_record'
require 'luca_record/io'

require 'minitest/autorun'

require 'luca_deal/setup'

def create_project(dir)
    LucaDeal::Setup.create_project(dir)
end
