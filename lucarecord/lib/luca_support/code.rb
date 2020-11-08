# frozen_string_literal: true

require 'date'
require 'securerandom'
require 'digest/sha1'
require 'luca_support/config'

# implement Luca IDs convention
module LucaSupport
  module Code
    module_function

    def encode_txid(num)
      txmap = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      l = txmap.length
      txmap[num / (l**2)] + txmap[(num % (l**2)) / l] + txmap[num % l]
    end

    def decode_txid(id)
      txmap = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      l = txmap.length
      txmap.index(id[0]) * (l**2) + txmap.index(id[1]) * l + txmap.index(id[2])
    end

    #
    # Day of month to code conversion.
    # Date, DateTime, String, Integer is valid input. If nil, returns empty String for consistency.
    #
    def encode_date(date)
      return '' if date.nil?

      index = date.day if date.respond_to?(:day)
      index ||= date.to_i if date.respond_to?(:to_i)
      index ||= 0
      raise 'Invalid date specified' if index < 1 || index > 31

      '0123456789ABCDEFGHIJKLMNOPQRSTUV'[index]
    end

    def decode_date(char)
      '0123456789ABCDEFGHIJKLMNOPQRSTUV'.index(char)
    end

    def delimit_num(num)
      num.to_s.reverse.gsub!(/(\d{3})(?=\d)/, '\1,').reverse!
    end

    # encode directory name from year and month.
    #
    def encode_dirname(date_obj)
      date_obj.year.to_s + encode_month(date_obj)
    end

    # Month to code conversion.
    # Date, DateTime, String, Integer is valid input. If nil, returns empty String for consistency.
    #
    def encode_month(date)
      return '' if date.nil?

      index = date.month if date.respond_to?(:month)
      index ||= date.to_i if date.respond_to?(:to_i)
      index ||= 0
      raise 'Invalid month specified' if index < 1 || index > 12

      '0ABCDEFGHIJKL'[index]
    end

    def decode_month(char)
      '0ABCDEFGHIJKL'.index(char)
    end

    def decode_term(char)
      m = /^([0-9]{4})([A-La-l])/.match(char)
      [m[1].to_i, decode_month(m[2])]
    end

    def issue_random_id
      Digest::SHA1.hexdigest(SecureRandom.uuid)
    end

    def decimalize(obj)
      case obj.class.name
      when 'Array'
        obj.map { |i| decimalize(i) }
      when 'Hash'
        obj.inject({}) { |h, (k, v)| h[k] = decimalize(v); h }
      when 'Integer'
        BigDecimal(obj.to_s)
      when 'String'
        /^[0-9\.]+$/.match(obj) ? BigDecimal(obj) : obj
      when 'Float'
        raise 'already float'
      else
        obj
      end
    end

    def readable(obj, len = LucaSupport::Config::DECIMAL_NUM)
      case obj.class.name
      when 'Array'
        obj.map { |i| readable(i) }
      when 'Hash'
        obj.inject({}) { |h, (k, v)| h[k] = readable(v); h }
      when 'BigDecimal'
        parts = obj.round(len).to_s('F').split('.')
        len < 1 ? parts.first : "#{parts[0]}.#{parts[1][0, len]}"
      else
        obj
      end
    end

    #
    # convert effective/defunct data into current hash on @date.
    # not parse nested children.
    #
    def parse_current(dat)
      {}.tap do |processed|
        dat.each { |k, _v| processed[k] = take_current(dat, k) }
      end
    end

    #
    # return current value with effective/defunct on target @date
    # For multiple attribues, return hash on other than 'val'. Examples are as bellows:
    #
    #   - effective: 2020-1-1
    #     val: 3000
    #   => 3000
    #
    #   - effective: 2020-1-1
    #     rank: 5
    #     point: 1000
    #   => { 'effective' => 2020-1-1, 'rank' => 5, 'point' => 1000 }
    #
    def take_current(dat, item)
      target = dat.dig(item)
      if target.is_a?(Array) && target.map(&:keys).flatten.include?('effective')
        latest = target
                 .filter { |a| Date.parse(a.dig('effective').to_s) < @date }
                 .max { |a, b| Date.parse(a.dig('effective').to_s) <=> Date.parse(b.dig('effective').to_s) }
        return nil if !latest.dig('defunct').nil? && Date.parse(latest.dig('defunct').to_s) < @date

        latest.dig('val') || latest
      else
        target
      end
    end

    def has_status?(dat, status)
      return false if dat['status'].nil?

      dat['status'].map { |h| h.key?(status) }
        .include?(true)
    end
  end
end
