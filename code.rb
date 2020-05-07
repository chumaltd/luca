require "date"
require "securerandom"
require "digest/sha1"

# implement Luca IDs convention
module Luca
  module Code

    def encode_txid(num)
      txmap = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      l = txmap.length
      txmap[num / (l**2)] + txmap[(num%(l**2)) / l] + txmap[num % l]
    end

    def decode_txid(id)
      txmap = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      l = txmap.length
      txmap.index(id[0]) * (l**2) + txmap.index(id[1]) * l + txmap.index(id[2])
    end

    def encode_date(date)
      return nil if date.nil?
      if date.class == Date or date.class == DateTime
        index = date.day
      elsif date.class == String or date.class == Integer
        index = date.to_i
      else
        return nil
      end
      return nil if index < 1 || index > 31
      "0123456789abcdefghijklmnopqrstuv"[index]
    end

    def decode_date(s)
      "0123456789abcdefghijklmnopqrstuv".index(s)
    end

    def encode_month(date)
      return nil if date.nil?
      if date.class == Date or date.class == DateTime
        index = date.month
      elsif date.class == String or date.class == Integer
        index = date.to_i
      else
        return nil
      end
      return nil if index < 1 || index > 12
      "0ABCDEFGHIJKL"[index]
    end

    def decode_month(s)
      "0ABCDEFGHIJKL".index(s)
    end

    def issue_random_id
      Digest::SHA1.hexdigest(SecureRandom.uuid)
    end
  end
end
