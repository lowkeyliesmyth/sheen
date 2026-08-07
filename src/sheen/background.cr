# TLDR; What functionality is in here?
# Terminal background detector: answers whether the background is dark so adaptive color pairs choose the appropriate variant.

require "../foundation"

module Sheen
  # Reports whether the terminal renders on a dark background, so that `AdaptiveColor` and `CompleteAdaptiveColor` can pick the correct light or dark variant.
  #
  # Detection is env-first and TTY-safe:
  # 1. `COLORFGBG`(a `fg;bg` pair of ANSI indices)
  # 2. An OSC11 background query written to *output* and read from *input* only when both are real TTYs
  # 3. Fallback to Dark (default black background) when nothing else answers
  def self.has_dark_background?(input : IO = STDIN, output : IO = STDOUT, env : Foundation::Env = Foundation::LiveEnv.new) : Bool
    if rgb = background_from_env(env)
      return dark?(rgb)
    end
    if rgb = background_from_query(input, output)
      return dark?(rgb)
    end
    true
  end

  # The background color extracted from `COLORFGBG` or nil when the var is absent or unparsable.  The last `;`-separated field is the ANSI background index.
  private def self.background_from_env(env : Foundation::Env) : Foundation::RGB?
    fgbg = env["COLORFGBG"]?
    return unless fgbg && fgbg.includes?(';')

    index = fgbg.split(';').last.to_i?
    return unless index && (0..255).includes?(index)
    Foundation::Palette::ANSI256[index]
  end

  # True when the color's HSL lightness `(max + min) / 2` is below 0.5 (the reference termenv's threshold)
  private def self.dark?(rgb : Foundation::RGB) : Bool
    channels = {rgb.r.to_f, rgb.g.to_f, rgb.b.to_f}
    ((channels.max + channels.min) / 2.0 / 255.0) < 0.5
  end

  # Queries the term background via OSC 11 (Operating System Command) sequence, returning its color or nil.
  #
  # Guarded to real TTYs only, and any failures (timeout, unsupported term, parsing error, etc.) return nil instead of raising so callers fall back to the heuristic cleanly.
  private def self.background_from_query(input : IO, output : IO) : Foundation::RGB?
    return unless input.is_a?(IO::FileDescriptor) && output.is_a?(IO::FileDescriptor)
    return unless input.tty? && output.tty?

    response = ""

    input.raw do
      # OSC 11 background query, then a CSI (Control Sequence Introducer) 6n CPR (cursor position report) as a fence. Terms that ignore OSC11 still answer CPR 6n, which prevents the read from blocking forever.
      output << "\e]11;?\e\\" << "\e[6n"
      output.flush
      input.read_timeout = 100.milliseconds
      response = read_osc_response(input)
    end
    parse_osc_color(response)
  rescue
    nil
  end

  # :nodoc:
  # Reads the terminal's reply to the combined OSC11 + CPR query, returning every byte through to the CPR terminator ('R'). This ensures that  the kernel input buffer is drained of any query responses that would otherwise dirty up the term visuals.
  def self.read_osc_response(io : IO) : String
    String.build do |buf|
      # OSC11 background reply plus the CPR fence sequence should always fit within 128 bytes with room to spare
      128.times do
        byte = begin
          io.read_byte
        rescue IO::TimeoutError
          nil
        end
        break unless byte
        buf << byte.unsafe_chr
        break if byte == 0x52_u8 # 'R' terminates the CPR 6n fence, the last byte of the reply
      end
    end
  end

  # :nodoc:
  # Parses an OSC 11 reply (like `"\e]11;rgb:1717/2b2b/3636\a"`) in to an `RGB`, taking the high byte of each 16-bit color channel.
  # Returns nil for any non-color reply.
  def self.parse_osc_color(response : String) : Foundation::RGB?
    body = response.lchop("\e]11;").rchop('\a').rchop("\e\\")
    return unless body.starts_with?("rgb:")

    channels = body.lchop("rgb:").split('/')
    return unless channels.size == 3 && channels.all? { |chn| chn.size >= 2 }
    Foundation::RGB.parse("#" + channels.map(&.[0, 2]).join)
  rescue
    nil
  end
end
