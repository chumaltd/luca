# frozen_string_literal: true

require_relative 'test_helper'

class LucaBook::DictTest < Minitest::Test
  include LucaRecord::IO

  def setup
    FileUtils.chdir(LucaSupport::Config::Pjdir)
    LucaBook::Setup.create_project(LucaSupport::Config::Pjdir)
    deploy('import-bank1.yaml', 'dict')
    deploy('sample-bankstatement.csv')
  end

  def teardown
    FileUtils.rm_rf(['data', 'dict', 'sample-bankstatement.csv'])
  end

  def test_that_it_has_valid_dictionary
    assert_nil LucaRecord::Dict.validate('base.tsv')
  end
end
