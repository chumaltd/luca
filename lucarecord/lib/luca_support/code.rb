require 'date'
require 'securerandom'
require 'digest/sha1'

# implement Luca IDs convention
module LucaSupport
  module Code
    module_function

    def encode_txid(num)
      txmap = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      l = txmap.length
      txmap[num / (l**2)] + txmap[(num%(l**2)) / l] + txmap[num % l]
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
      num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
    end

    #
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

    def take_active(dat, item, attr='val')
      target = dat.dig(item)
      if target.class.name == 'Array'
        target.filter { |a| Date.parse(a.dig('effective').to_s) < @date }
          .map { |a|
          return nil if ! a.dig('defunct').nil? && Date.parse(a.dig('defunct').to_s) < @date

          a
        }
          .max { |a, b| Date.parse(a.dig('effective').to_s) <=> Date.parse(b.dig('effective').to_s) }
          .dig(attr)
      else
        target
      end
    end
  end
end