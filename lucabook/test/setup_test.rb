# frozen_string_literal: true

require_relative 'test_helper'

class LucaBook::SetupTest < Minitest::Test
  include LucaRecord::IO

  def setup
    FileUtils.chdir(LucaSupport::CONST.pjdir)
  end

  def teardown
    FileUtils.rm_rf(['data', 'dict', 'config.yml'])
  end

  def test_that_it_create_resources
    LucaBook::Setup.create_project
    assert Dir.exist? 'data/journals'
    assert File.exist? 'data/balance/start.tsv'
    assert File.exist? 'dict/base.tsv'
    assert File.exist? 'config.yml'
  end

  def test_that_it_accepts_specified_dir
    LucaBook::Setup.create_project nil, 'test'
    assert File.exist? 'test/data/balance/start.tsv'
    FileUtils.rm_rf(['test'])
  end
end
