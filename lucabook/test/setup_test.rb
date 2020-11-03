# frozen_string_literal: true

require_relative 'test_helper'

class LucaBook::InvoiceTest < Minitest::Test
  include LucaRecord::IO

  def setup
    FileUtils.chdir(LucaSupport::Config::Pjdir)
  end

  def teardown
    FileUtils.rm_rf(['data', 'dict'])
  end

  def test_that_it_create_resources
    LucaBook::Setup.create_project
    assert Dir.exist? 'data/journals'
    assert File.exist? 'dict/base.tsv'
  end
end
