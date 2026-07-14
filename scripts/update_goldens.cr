require "../examples/examples"

# Regenerates the on-disk golden files for TrueColor-pinned examples.

GOLDEN_EXAMPLES = [] of String

if GOLDEN_EXAMPLES.empty?
  puts "no golden examples registered yet"
else
  GOLDEN_EXAMPLES.each do |name|
    renderer = Sheen::Renderer.new(IO::Memory.new)
    renderer.color_profile = Foundation::Profile::TrueColor
    renderer.has_dark_background = true

    output = Examples.run(name, renderer)
    path = File.join("spec", "examples", "golden", "#{name}.ansi")
    Dir.mkdir_p(File.dirname(path))
    File.write(path, output)
    puts "wrote #{path} (#{output.bytesize} bytes)"
  end
end
