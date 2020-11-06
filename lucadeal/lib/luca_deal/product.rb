# frozen_string_literal: true

require 'luca_deal/version'

require 'date'
require 'yaml'
require 'pathname'
require 'luca_record'

module LucaDeal
  class Product < LucaRecord::Base
    @dirname = 'products'
    @required = ['items']

    def list_name
      list = self.class.all.map { |dat| parse_current(dat) }
      YAML.dump(list).tap { |l| puts l }
    end

    # Save data with hash in Product format. Simple format is also available as bellows:
    #   {
    #      name: 'item_name(required)', price: 'item_price', qty: 'item_qty',
    #      initial: { name: 'item_name', price: 'item_price', qty: 'item_qty' }
    #   }
    def self.create(obj)
      if obj[:name].nil?
        h = obj
      else
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
      end
      super(h)
    end
  end
end
