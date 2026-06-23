require "./color_space"

module Foundation
  # xterm 256 color palette: index -> sRGB. The target set for downampling truecolor to ANSI256/ANSI16 by nearest  ΔE76 perceptual distance.
  #
  # See reference xterm 256 color chart: https://jonasjacek.github.io/colors/
  # - Indices 0-15: conventional xterm system colors
  # - Indices 16-231: a 6x6x6 color cube where each channel increment follows {0, 95, 135, 175, 215, 255} and index = 16 + 36*r + 6*g + b.
  #    So for example, the color at cube position (r=1, g=2, b=3) → RGB (95, 135, 175) → palette index 16 + 36 + 12 + 3 = 67.
  # - Indices 232-255: 24-step grayscale ramp, where value = 8 + 10*i
  module Palette
    # Indices 0-15 ANSI system colors
    BASE_16 = [
      "#000000", "#800000", "#008000", "#808000",
      "#000080", "#800080", "#008080", "#c0c0c0",
      "#808080", "#ff0000", "#00ff00", "#ffff00",
      "#0000ff", "#ff00ff", "#00ffff", "#ffffff",
    ].map { |hex| RGB.parse(hex) }

    # The six color cube levels
    CUBE_LEVELS = {0_u8, 95_u8, 135_u8, 175_u8, 215_u8, 255_u8}

    # All 256 palette colors index 0-255.
    ANSI256 = begin
      colors = Array(RGB).new(256)
      colors.concat(BASE_16)
      CUBE_LEVELS.each do |red|
        CUBE_LEVELS.each do |green|
          CUBE_LEVELS.each do |blue|
            colors << RGB.new(red, green, blue)
          end
        end
      end
      24.times do |i|
        v = (8 + i * 10).to_u8
        colors << RGB.new(v, v, v)
      end
      colors
    end
  end
end
