def create_chunks(message_count, message_size, fragment_count, chop_size)
  frames = message_count.times.flat_map do
    create_frames(message_size, fragment_count)
  end
  frames.each_slice(chop_size).map { |c| c.pack('C*') }
end

def create_frames(message_size, fragments)
  message   = message_size.times.map { rand(0x20..0x7e) }
  frag_size = (message_size / fragments.to_f).ceil

  message.each_slice(frag_size).with_index.flat_map do |bytes, i|
    final  = (i == fragments - 1)
    opcode = (i == 0) ? 1 : 0

    frame(final, opcode, bytes)
  end
end

def frame(final, opcode, bytes)
  masked = 0x80
  mask   = masked.zero? ? [] : (1..4).map { rand 0xff }
  length = bytes.size

  bytes.each.with_index do |byte, i|
    bytes[i] ^= mask[i % 4] unless masked.zero?
  end

  frame = []
  frame << ((final ? 0x80 : 0x00) | opcode)

  if length <= 125
    frame << (masked | length)
  elsif length <= 65535
    frame << (masked | 126)
    frame += [length].pack('n').bytes
  else
    frame << (masked | 127)
    frame += [length].pack('Q>').bytes
  end

  frame + mask + bytes
end
