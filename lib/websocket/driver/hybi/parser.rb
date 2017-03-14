module WebSocket
  class Driver
    class Hybi

      class Parser
        def initialize(driver, require_masking)
          @driver = driver
          @require_masking = require_masking

          @reader  = StreamReader.new
          @stage   = 0
          @frame   = nil
          @message = nil
        end

        def parse(chunk)
          @reader.push(chunk)
          buffer = true

          while buffer
            case @stage
              when 0 then
                buffer = @reader.read(1)
                parse_opcode(buffer.getbyte(0)) if buffer

              when 1 then
                buffer = @reader.read(1)
                parse_length(buffer.getbyte(0)) if buffer

              when 2 then
                buffer = @reader.read(@frame.length_bytes)
                parse_extended_length(buffer) if buffer

              when 3 then
                buffer = @reader.read(4)
                if buffer
                  @stage = 4
                  @frame.masking_key = buffer
                end

              when 4 then
                buffer = @reader.read(@frame.length)

                if buffer
                  @stage = 0
                  emit_frame(buffer)
                end

              else
                buffer = nil
            end
          end
        end

      private

        def parse_opcode(octet)
          rsvs = [RSV1, RSV2, RSV3].map { |rsv| (octet & rsv) == rsv }

          @frame = Frame.new

          @frame.final  = (octet & FIN) == FIN
          @frame.rsv1   = rsvs[0]
          @frame.rsv2   = rsvs[1]
          @frame.rsv3   = rsvs[2]
          @frame.opcode = (octet & OPCODE)

          @stage = 1

          unless @driver.__send__(:valid_frame_rsv?, @frame.rsv1, @frame.rsv2, @frame.rsv3, @frame.opcode)
            return parser_error(:protocol_error,
                "One or more reserved bits are on: reserved1 = #{@frame.rsv1 ? 1 : 0}" +
                ", reserved2 = #{@frame.rsv2 ? 1 : 0 }" +
                ", reserved3 = #{@frame.rsv3 ? 1 : 0 }")
          end

          unless OPCODES.values.include?(@frame.opcode)
            return parser_error(:protocol_error, "Unrecognized frame opcode: #{@frame.opcode}")
          end

          unless MESSAGE_OPCODES.include?(@frame.opcode) or @frame.final
            return parser_error(:protocol_error, "Received fragmented control frame: opcode = #{@frame.opcode}")
          end

          if @message and OPENING_OPCODES.include?(@frame.opcode)
            return parser_error(:protocol_error, 'Received new data frame but previous continuous frame is unfinished')
          end
        end

        def parse_length(octet)
          @frame.masked = (octet & MASK) == MASK
          @frame.length = (octet & LENGTH)

          if @frame.length >= 0 and @frame.length <= 125
            @stage = @frame.masked ? 3 : 4
            return unless check_frame_length
          else
            @stage = 2
            @frame.length_bytes = (@frame.length == 126) ? 2 : 8
          end

          if @require_masking and not @frame.masked
            return parser_error(:unacceptable, 'Received unmasked frame but masking is required')
          end
        end

        def parse_extended_length(buffer)
          @frame.length = buffer.unpack(PACK_FORMATS[buffer.bytesize]).first
          @stage = @frame.masked ? 3 : 4

          unless MESSAGE_OPCODES.include?(@frame.opcode) or @frame.length <= 125
            return parser_error(:protocol_error, "Received control frame having too long payload: #{@frame.length}")
          end

          return unless check_frame_length
        end

        def check_frame_length
          length = @message ? @message.data.bytesize : 0

          if length > MAX_MESSAGE_LENGTH - @frame.length
            parser_error(:too_large, 'WebSocket frame length too large')
            false
          else
            true
          end
        end

        def emit_frame(buffer)
          frame    = @frame
          opcode   = frame.opcode
          payload  = frame.payload = Mask.mask(buffer, @frame.masking_key)
          bytesize = payload.bytesize
          bytes    = payload.bytes.to_a

          @frame = nil

          code   = 0
          reason = nil

          case opcode
            when OPCODES[:continuation] then
              return parser_error(:protocol_error, 'Received unexpected continuation frame') unless @message
              @message << frame

            when OPCODES[:text], OPCODES[:binary] then
              @message = Message.new
              @message << frame

            when OPCODES[:close] then
              if frame.length == 0
                code   = DEFAULT_ERROR_CODE
                reason = ''
              elsif frame.length >= 2
                code   = payload.unpack(PACK_FORMATS[2]).first
                reason = bytes[2..-1]
              end

              unless ERROR_CODES.include?(code) or
                     (code >= MIN_RESERVED_ERROR and code <= MAX_RESERVED_ERROR)
                code = ERRORS[:protocol_error]
              end

              @driver.__send__(:handle_close, code, reason || '')

            when OPCODES[:ping] then
              @driver.__send__(:handle_ping, payload)

            when OPCODES[:pong] then
              @driver.__send__(:handle_pong, payload)
          end

          emit_message if frame.final and MESSAGE_OPCODES.include?(opcode)
        end

        def emit_message
          @driver.__send__(:handle_message, @message.opcode, @message.rsv1, @message.rsv2, @message.rsv3, @message.data)
          @message = nil
        end

        def parser_error(type, message)
          @stage = -1
          @driver.__send__(:handle_error, ERRORS[type], message)
        end
      end

    end
  end
end
