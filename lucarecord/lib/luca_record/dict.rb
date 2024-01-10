# frozen_string_literal: true

require 'csv'
require 'date'
require 'fileutils'
require 'yaml'
require 'pathname'
require 'luca_support'

# Low level API
#
module LucaRecord
  class Dict
    include LucaSupport::Code

    def initialize(file = @filename)
      @path = self.class.dict_path(file)
      set_driver
    end

    # Search code with n-gram word.
    # If dictionary has Hash or Array, it returns [label, options].
    #
    def search(word, default_word = nil, main_key: 'label', options: nil)
      definitions_lazyload
      res, score = max_score_code(word.gsub(/[[:space:]]/, ''))
      return default_word if score < 0.4

      case res
      when Hash
        hash2multiassign(res, main_key, options: options)
      when Array
        res.map { |item| hash2multiassign(item, main_key, options: options) }
      else
        res
      end
    end

    # Search with unique code.
    #
    def dig(*args)
      @data.dig(*args)
    end

    # Separate main item from other options.
    # If options specified as Array of string, it works as safe list filter.
    #
    def hash2multiassign(obj, main_key = 'label', options: nil)
      options = {}.tap do |opt|
        obj.map do |k, v|
          next if k == main_key
          next if !options.nil? && !options.include?(k)

          opt[k.to_sym] = v
        end
      end
      [obj[main_key], options.compact]
    end

    # Load CSV with config options
    #
    def load_csv(path)
      CSV.read(path, headers: true, encoding: "#{@config.dig('encoding') || 'utf-8'}:utf-8").each do |row|
        yield row
      end
    end

    # load dictionary data
    #
    def self.load(file = @filename)
      case File.extname(file)
      when '.tsv', '.csv'
        load_tsv_dict(dict_path(file))
      when '.yaml', '.yml'
        YAML.safe_load(File.read(dict_path(file)), permitted_classes: [Date])
      else
        raise 'cannot load this filetype'
      end
    end

    # generate dictionary from TSV file. Minimum assumption is as bellows:
    # 1st row is converted symbol.
    #
    # * row[0] is 'code'. Converted hash keys
    # * row[1] is 'label'. Should be human readable labels
    # * after row[2] can be app specific data
    #
    def self.load_tsv_dict(path)
      {}.tap do |dict|
        CSV.read(path, headers: true, col_sep: "\t", encoding: 'UTF-8').each do |row|
          {}.tap do |entry|
            row.each do |header, field|
              next if row.index(header).zero?

              entry[header.to_sym] = field unless field.nil?
            end
            dict[row[0]] = entry
          end
        end
      end
    end

    def self.validate(filename, target_key = :label)
      errors = load(filename).map { |k, v| v[target_key].nil? ? k : nil }.compact
      if errors.empty?
        puts 'No error detected.'
        nil
      else
        puts "Key #{errors.join(', ')} has nil #{target_key}."
        errors.count
      end
    end

    private

    def set_driver
      @data = self.class.load(@path)
      @config = @data['config']
      @definitions = @data['definitions']
    end

    # Build Reverse dictionary for TSV data
    #
    def definitions_lazyload
      @definitions ||= @data.each_with_object({}) { |(k, entry), h| h[entry[:label]] = k if entry[:label] }
    end

    def self.dict_path(filename)
      Pathname(CONST.pjdir) / 'dict' / filename
    end

    def self.reverse(dict)
      dict.map{ |k, v| [v[:label], k] }.to_h
    end

    def max_score_code(str)
      res = @definitions.map do |k, v|
        [v, match_score(str, k, 2)]
      end
      res.max { |x, y| x[1] <=> y[1] }
    end
  end
end
