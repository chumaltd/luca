# frozen_string_literal: true

require_relative 'test_helper'

class SampleRecord < LucaRecord::Base
  @dirname = 'samples'
end

class LucaRecord::IoWriteTest < Minitest::Test
  include LucaRecord::IO

  def setup
    FileUtils.chdir(LucaSupport::Config::Pjdir)
    LucaDeal::Setup.create_project(LucaSupport::Config::Pjdir)
  end

  def teardown
    FileUtils.rm_rf(['data', 'config.yml'])
  end

  def test_that_it_create_and_update_record
    id = SampleRecord.create('name' => 'SampleProduct1', 'initial' => { 'name' => 'Initial fee', 'price' => 50000 })
    assert_equal 1, Dir.glob('data/samples/*/*').length
    assert_equal 1, SampleRecord.all.count
    load_data = SampleRecord.find(id)
    assert_equal 50000, load_data['initial']['price']
    assert_equal 'SampleProduct1', load_data['name']
    assert_nil load_data['update']
    load_data['update'] = 1
    SampleRecord.save(load_data)
    assert_equal 1, Dir.glob('data/samples/*/*').length
    assert_equal 1, SampleRecord.all.count
    load_data2 = SampleRecord.find(id)
    assert_equal 50000, load_data['initial']['price']
    assert_equal 'SampleProduct1', load_data['name']
    assert_equal 1, load_data['update']
  end

  def test_that_it_delete_record
    id = SampleRecord.create('name' => 'SampleProduct1', 'initial' => { 'name' => 'Initial fee', 'price' => 50000 })
    assert_equal 1, Dir.glob('data/samples/*/*').length
    SampleRecord.delete(id)
    assert_equal 0, Dir.glob('data/samples/*/*').length
    assert_equal 0, SampleRecord.all.count
  end
end
