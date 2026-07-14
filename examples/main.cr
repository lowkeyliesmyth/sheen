require "./examples"

# CLI dispatcher for the reference Sheen consumer examples.
# Renders one named example to STDOUT through the process-global renderer so it honors the detected color profile.
#
# Usage: `crystal run examples/main.cr -- <example>`
name = ARGV[0]?

case name
when nil
  STDERR.puts "usage: crystal run examples/main.cr -- <example>"
  STDERR.puts "available examples: #{Examples.names.join(", ")}"
  exit 1
when "all"
  Examples.names.each do |ex_name|
    puts "=== #{ex_name} ==="
    puts Examples.run(ex_name)
    puts
  end
else
  begin
    puts Examples.run(name)
  rescue ex : Examples::UnknownExample
    STDERR.puts ex.message
    exit 1
  end
end
