# typed: false
# frozen_string_literal: true

module Base32
  class NormalizedInteger
    def initialize(v)
      @value = v
    end


    def each_byte(&blk)
      v = @value
      while v > 0
        yield v & 255
        v >>= 8
      end
    end
  end


  class Crockford
    ENCODE = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
    DECODE = {
      "0" => 0,
      "1" => 1,
      "2" => 2,
      "3" => 3,
      "4" => 4,
      "5" => 5,
      "6" => 6,
      "7" => 7,
      "8" => 8,
      "9" => 9,
      "A" => 10,
      "B" => 11,
      "C" => 12,
      "D" => 13,
      "E" => 14,
      "F" => 15,
      "G" => 16,
      "H" => 17,
      "J" => 18,
      "K" => 19,
      "M" => 20,
      "N" => 21,
      "P" => 22,
      "Q" => 23,
      "R" => 24,
      "S" => 25,
      "T" => 26,
      "V" => 27,
      "W" => 28,
      "X" => 29,
      "Y" => 30,
      "Z" => 31
    }


    def self.encode(v)
      if v.respond_to?(:integer?) && v.integer?
        normalized = NormalizedInteger.new(v)
      else
        normalized = v.reverse
      end

      n = 0
      bits = 0
      res = String.new
      normalized.each_byte do |b|
        n += b << bits
        bits += 8

        while bits >= 5 do
          res << ENCODE[n & 31]
          n >>= 5
          bits -= 5
        end
      end
      res << ENCODE[n & 31] if n != 0
      res << "0" if res.empty?

      res.reverse
    end

    def self.hypenate(v)
      v.reverse.gsub(/(\w\w\w\w\w)/, "\\1-").gsub(/-$/, "").downcase.reverse
    end

    def self.decode(v, to = :binary_string)
      normalized = v.upcase.tr("OILU", "011").tr("-", "").reverse

      n = 0
      bits = 0
      res = String.new
      res.force_encoding("binary") if res.respond_to?(:force_encoding)
      normalized.each_byte do |b|
        n += (DECODE[b.chr] << bits)
        bits += 5

        while bits >= 8 do
          res << (n & 255).chr
          n >>= 8
          bits -= 8
        end
      end
      res << n if n != 0
      res << 0 if res.empty?
      res = res.reverse

      case to
      when :integer
        v = 0
        res.each_byte do |byte|
          v <<= 8
          v |= byte
        end
        v
      else
        res
      end
    end
  end
end
