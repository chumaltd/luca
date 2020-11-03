# frozen_string_literal: true

require 'bundler'
Bundler.require

require 'simplecov'
SimpleCov.start

require 'fileutils'
require 'pathname'
require 'luca_book'
require 'luca_record/io'

require 'minitest/autorun'
