require "../src/sheen"

# Reference consumers of Sheen, also functioning as a full e2e acceptance test.
# Each example consumer is a pure function registered by name so it can be run from the CLI and asserted on in specs.

module Examples
  class UnknownExample < Exception
    def initialize(name : String, available : Array(String))
      super("unknown example #{name.inspect}. available examples: #{available.join(", ")}")
    end
  end

  @@registry = {} of String => Proc(String)

  # Registers *block* as the example named *name* (eg "layout" or "tree-simple".
  def self.register(name : String, &block : -> String) : Nil
    @@registry[name] = block
  end

  # The registered example names, sorted.
  def self.names : Array(String)
    @@registry.keys.sort!
  end

  # Renders the example named *name* example consumer.
  #
  # Raises `UnknownExample` if nothing is registered under *name*.
  def self.run(name : String) : String
    block = @@registry[name]?
    raise UnknownExample.new(name, names) unless block
    block.call
  end
end

# Example reference implementations self-register on require. Add one line per example reference.
#
require "./layout/document"
