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

def deploy(filename, subdir = nil)
  if subdir
    FileUtils.cp("#{__dir__}/#{filename}", Pathname(LucaSupport::PJDIR) / subdir / filename)
  else
    FileUtils.cp("#{__dir__}/#{filename}", Pathname(LucaSupport::PJDIR) / filename)
  end
end
