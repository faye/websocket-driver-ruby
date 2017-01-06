module WebSocket
  class Driver
    class Hybi

      class Unparser
        def initialize(driver, masking)
          @masking = masking
        end

        def frame(final, rsv1, rsv2, rsv3, opcode, masking_key, payload)
          length = payload.bytesize
          buffer = []
          masked = @masking ? MASK : 0

          buffer[0] = (final ? FIN : 0) |
                      (rsv1 ? RSV1 : 0) |
                      (rsv2 ? RSV2 : 0) |
                      (rsv3 ? RSV3 : 0) |
                      opcode

          if length <= 125
            buffer[1] = masked | length
          elsif length <= 65535
            buffer[1] = masked | 126
            buffer[2..3] = [length].pack(PACK_FORMATS[2]).bytes.to_a
          else
            buffer[1] = masked | 127
            buffer[2..9] = [length].pack(PACK_FORMATS[8]).bytes.to_a
          end

          if @masking
            buffer.concat(masking_key.bytes.to_a)
            Mask.mask(payload, masking_key)
          end

          buffer.concat(payload.bytes.to_a)

          buffer.pack('C*')
        end
      end

    end
  end
end
