require "../foundation"

module Sheen
  # Terminal renderer holding the color profile and background darkness used to resolve and downsample colors at render time. Inspired by lipglossv1's Renderer.
  class Renderer
    # The output the profile is detected from and that rendering targets.
    property output : IO

    def initialize(@output : IO = STDOUT)
      @color_profile = nil.as(Foundation::Profile?)
      @has_dark_background = nil.as(Bool?)
    end

    # The color profile, detected from *@output* on first use, if not already set explicitly.
    def color_profile : Foundation::Profile
      @color_profile ||= Foundation::Profile.detect(@output)
    end

    # Bypasses detection and sets the color profile explicitly, primarily used for testing
    def color_profile=(profile : Foundation::Profile) : Foundation::Profile
      @color_profile = profile
    end

    # Detects if the terminal background is dark, caching the result on first read.
    #
    # Explicitly override with `has_dark_background`
    def has_dark_background? : Bool
      bg = @has_dark_background
      return bg unless bg.nil?
      bg.nil? ? (@has_dark_background = true) : bg
    end

    # Forces background darkness value
    def has_dark_background=(value : Bool) : Bool
      @has_dark_background = value
    end
  end

  # Process-global default renderer. Configure it directly, eg `Sheen.renderer.color_profile = Foundation::Profile::TrueColor`.
  #
  # Or replace it wholesale: `Sheen.renderer = Sheen::Renderer.new(io)`
  class_property renderer : Renderer = Renderer.new
end
