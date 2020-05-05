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

    def encode_date(date_obj)
      "0123456789abcdefghijklmnopqrstuv"[date_obj.day]
    end

    def decode_date(s)
      "0123456789abcdefghijklmnopqrstuv".index(s)
    end

    def encode_month(date_obj)
      "0ABCDEFGHIJKL"[date_obj.month]
    end

    def decode_month(s)
      "0ABCDEFGHIJKL".index(s)
    end

  end
end
