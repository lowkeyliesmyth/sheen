# ameba:disable Lint/SpecFilename
require "../spec_helper"
require "../../examples/examples"

# Renderer bound to an in-memory buffer with the color profile pinned to Ascii and a dark background.
# Yields plaintext so an example output can be asserted against.
def ascii_renderer : Sheen::Renderer
  renderer = Sheen::Renderer.new(IO::Memory.new)
  renderer.color_profile = Foundation::Profile::Ascii
  renderer.has_dark_background = true
  renderer
end

# Same as `ascii_renderer`, but pinned to Truecolor for comparison of full-color output.
def truecolor_renderer : Sheen::Renderer
  renderer = Sheen::Renderer.new(IO::Memory.new)
  renderer.color_profile = Foundation::Profile::TrueColor
  renderer.has_dark_background = true
  renderer
end

# Asserts that no visible line in *output* exceeds *width* cells. ANSI-aware, so escape sequences do not contribute to any width measurement.
def assert_within_width(output : String, width : Int32) : Nil
  return if output.empty?
  widest = output.lines.max_of { |line| Foundation.string_width(line) }
  widest.should be <= width
end

# Asserts that *output*, stripped of any ANSI escapes, contains *text*.
def assert_contains_stripped(output : String, text : String) : Nil
  Foundation.strip(output).should contain(text)
end
