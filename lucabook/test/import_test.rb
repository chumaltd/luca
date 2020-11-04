# frozen_string_literal: true

require_relative 'test_helper'

class LucaBook::ImportTest < Minitest::Test
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

  def test_that_it_create_journals
    LucaBook::Import.new('sample-bankstatement.csv', 'bank1').import_csv
    assert_equal 4, Dir.glob('data/journals/9999L/*').length
    assert_equal 1, Dir.glob('data/journals/9999L/9001*').length
    assert_equal 1, Dir.glob('data/journals/9999L/F001*').length
    assert_equal 1, Dir.glob('data/journals/9999L/F002*').length
    assert_equal 1, Dir.glob('data/journals/9999L/V001*').length
    # with Saving accounts code
    assert_equal 4, Dir.glob('data/journals/9999L/*-*113*').length
    assert_equal 1, Dir.glob('data/journals/9999L/*-*511*').length
    assert_equal 1, Dir.glob('data/journals/9999L/*-*514*').length
    assert_equal 1, Dir.glob('data/journals/9999L/*-*C1E*').length
    assert_equal 1, Dir.glob('data/journals/9999L/*-*D11*').length
  end
end
