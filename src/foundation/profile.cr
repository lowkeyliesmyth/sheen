module Foundation
  # The color capability of an output, from least to most capable. Mirrors termenv detection path from termenv.
  enum Profile
    NoTTY     # not a term, hide that color
    Ascii     # a terminal, but weak and bleak with no color
    ANSI      # 16 colors
    ANSI256   # 256 color
    TrueColor # 24bit color

    # Detects the color profile from *io*'s TTY status and *env*. Honors NO_COLOR (no-color.org) and FORCE_COLOR (force-color.org). *env* only needs respond to `[]?`.
    def self.detect(io : IO = STDOUT, env = ENV) : Profile
      return Ascii if env_no_color?(env)

      base = from_environment(io, env)
      # FORCE_COLOR upgrades a no-color result to at least 16 colors
      return ANSI if force_color?(env) && (base.no_tty? || base.ascii?)
      base
    end

    # The profile implied by TTY status and TERM/COLORTERM, ignoring NO_COLOR.
    private def self.from_environment(io : IO, env) : Profile
      return NoTTY unless io.tty?
      return TrueColor if env["GOOGLE_CLOUD_SHELL"]? == "true"

      term = env["TERM"]? || ""

      if profile = from_colorterm(env, term)
        return profile
      end

      from_term(term)
    end

    # The profile implied by COLORTERM, or nil if COLORTERM doesn't apply.
    private def self.from_colorterm(env, term : String) : Profile?
      case (env["COLORTERM"]? || "").downcase
      when "24bit", "truecolor"
        # screen/tmux caveat: screen only does ANSI256 unless it's tmux?
        if term.starts_with?("screen") && env["TERM_PROGRAM"]? != "tmux"
          ANSI256
        else
          TrueColor
        end
      when "yes", "true"
        ANSI256
      end
    end

    # The profile implied by TERM.
    private def self.from_term(term : String) : Profile
      case term
      when "alacritty", "contour", "rio", "wezterm", "xterm-ghostty", "xterm-kitty"
        TrueColor
      when "linux", "xterm"
        ANSI
      when .includes?("256color")
        ANSI256
      when .includes?("color"), .includes?("ansi")
        ANSI
      else
        Ascii
      end
    end

    # True when NO_COLOR is present and not overridden by FORCE_COLOR.
    private def self.env_no_color?(env) : Bool
      if (nc = env["NO_COLOR"]?) && !nc.empty?
        !force_color?(env)
      else
        false
      end
    end

    # True when FORCE_COLOR is set to a non-"0" value.
    private def self.force_color?(env) : Bool
      if forced = env["FORCE_COLOR"]?
        return forced != "0"
      end
      false
    end
  end
end
