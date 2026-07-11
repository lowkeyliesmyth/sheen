# TLDR; What functionality is in here?
# Position abstraction: a normalized fraction along an axis that alignment and placement operations interpret consistently.

module Sheen
  # A position along an axis, used for alignment, joining, and placement.
  #
  # - 0.0: the start at top/left
  # - 0.5: the center
  # - 1.0: the end at bottom/right
  #
  # Values outside 0.0..1.0 are clamped when applied
  struct Position
    getter value : Float64

    # Creates a position from a raw fraction, clamped only on use via `#fraction`
    def initialize(@value : Float64)
    end

    # Clamps *@value* to 0.0..1.0
    def fraction : Float64
      value.clamp(0.0, 1.0)
    end

    # The start of an axis
    TOP  = Position.new(0.0)
    LEFT = Position.new(0.0)

    # The middle of an axis
    CENTER = Position.new(0.5)

    # The end of an axis
    BOTTOM = Position.new(1.0)
    RIGHT  = Position.new(1.0)
  end
end
