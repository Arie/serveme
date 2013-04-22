module ActiveSupport
  module Multibyte
    module Unicode

      def tidy_byte(byte)
        if byte.is_a? Integer
          if byte < 160
            [database.cp1252[byte] || byte].pack("U").unpack("C*")
          elsif byte < 192
            [194, byte]
          else
            [195, byte - 64]
          end
        else
          byte
        end
      end

    end
  end
end
