# frozen_string_literal: true

require 'luca_deal/version'

require 'date'
require 'yaml'
require 'pathname'
require 'luca_record'

module LucaDeal
  class Product < LucaRecord::Base
    @dirname = 'products'

    def list_name
      list = self.class.all.map { |dat| parse_current(dat) }
      YAML.dump(list).tap { |l| puts l }
    end

    def self.create(obj)
      raise ':name is required' if obj[:name].nil?

      items = [{
                 'name' => obj[:name],
                 'price' => obj[:price] || 0,
                 'qty' => obj[:qty] || 1
               }]
      if obj[:initial]
        items << {
          'name' => obj.dig(:initial, :name),
          'price' => obj.dig(:initial, :price) || 0,
          'qty' => obj.dig(:initial, :qty) || 1,
          'type' => 'initial'
        }
      end
      h = {
        'name' => obj[:name],
        'items' => items
      }
      super(h)
    end
  end
end
