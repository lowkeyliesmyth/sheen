# TLDR; What functionality is in here?
# The List structure as a wrapper around Tree. Custom enumerators are here, but most delegates to Tree.

require "./tree"

module Sheen
  # A list of items rendered with a leading enumerator indicator.
  #
  # `List` is a wrapper over `Tree`, and all styling methods delegate to the wrapped `Tree`. Items become tree children (lol) and a nested `List` nests as a subtree.
  class List
    ROMAN_SYMBOLS = %w[M CM D CD C XC L XL X IX V IV I]
    ROMAN_VALUES  = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
    ALPHA_LEN     = 26

    # Build a list of *items*. Uses the bullet enumerator and a single space indent as defaults.
    def initialize(*items)
      @tree = Tree::Branch.new
        .enumerator(Enumerators::Bullet.to_proc)
        .indenter(->List.space_indenter(Tree::Children, Int32))
      items.each { |value| item(value) }
    end

    # Builtin enumerator styles.
    enum Enumerators
      Alpha
      Arabic
      Asterisk
      Bullet
      Dash
      Roman

      # The `Enumerator` proc backing this style member.

      def to_proc : Tree::Enumerator
        case self
        in .alpha?    then ->List.alpha(Tree::Children, Int32)
        in .arabic?   then ->List.arabic(Tree::Children, Int32)
        in .asterisk? then ->List.asterisk(Tree::Children, Int32)
        in .bullet?   then ->List.bullet(Tree::Children, Int32)
        in .dash?     then ->List.dash(Tree::Children, Int32)
        in .roman?    then ->List.roman(Tree::Children, Int32)
        end
      end
    end

    # Appends a nested *value* list, which nests as a subtree
    #
    # Returns self.
    def item(value : List) : List
      @tree.child(value.tree)
      self
    end

    # Appends *value* to an item.
    #
    # Returns self.
    def item(value) : List
      @tree.child(value)
      self
    end

    # Appends each of the *values* as an item
    #
    # Returns self.
    def items(*values) : List
      values.each { |value| item(value) }
      self
    end

    # The arabic-numeral enumerator.
    def self.arabic(_items : Tree::Children, index : Int32) : String
      "#{index + 1}."
    end

    # The upcased alphabet enumerator.
    def self.alpha(_items : Tree::Children, index : Int32) : String
      i = index
      if i >= ALPHA_LEN * ALPHA_LEN + ALPHA_LEN
        "#{('A'.ord + i // ALPHA_LEN // ALPHA_LEN - 1).chr}#{('A'.ord + (i // ALPHA_LEN) % ALPHA_LEN - 1).chr}#{('A'.ord + i % ALPHA_LEN).chr}."
      elsif i >= ALPHA_LEN
        "#{('A'.ord + i // ALPHA_LEN - 1).chr}#{('A'.ord + i % ALPHA_LEN).chr}."
      else
        "#{('A'.ord + i % ALPHA_LEN).chr}."
      end
    end

    # The roman numeral enumerator.
    def self.roman(_items : Tree::Children, index : Int32) : String
      i = index
      String.build do |bldr|
        ROMAN_VALUES.each_with_index do |value, v|
          while i >= value - 1
            i -= value
            bldr << ROMAN_SYMBOLS[v]
          end
        end
        bldr << '.'
      end
    end

    # The bullet enumerator.
    def self.bullet(_items : Tree::Children, _index : Int32) : String
      "•"
    end

    # The dash enumerator.
    def self.dash(_items : Tree::Children, _index : Int32) : String
      "-"
    end

    # The asterisk enumerator.
    def self.asterisk(_items : Tree::Children, _index : Int32) : String
      "*"
    end

    # The space indenter. This is the list default.
    def self.space_indenter(_items : Tree::Children, _index : Int32) : String
      " "
    end

    # Sets the enumerator generating each item's prefix.
    #
    # Returns self.
    def enumerator(enumr : Tree::Enumerator) : List
      @tree.enumerator(enumr)
      self
    end

    # Sets the enumerator from a *block*.
    #
    # Returns self.
    def enumerator(&block : Tree::Children, Int32 -> String) : List
      @tree.enumerator(&block)
      self
    end

    # Convenience method to set one of the builtin enumerator styles by *kind*. eg `enumerator(:roman)`
    #
    # Returns self.
    def enumerator(kind : Enumerators) : List
      @tree.enumerator(kind.to_proc)
      self
    end

    # Sets one static *style* for every enumerator prefix.
    #
    # Returns self.
    def enumerator_style(style : Style) : List
      @tree.enumerator_style(style)
      self
    end

    # Sets the enumerator style *block*, invoked per item.
    #
    # Returns self.
    def enumerator_style(&block : Tree::Children, Int32 -> Style) : List
      @tree.enumerator_style(&block)
      self
    end

    # Sets one static *style* for every item's value
    #
    # Returns self
    def item_style(style : Style) : List
      @tree.item_style(style)
      self
    end

    # Sets the item style *block*, invoked per item.
    #
    # Returns self.
    def item_style(&block : Tree::Children, Int32 -> Style) : List
      @tree.item_style(&block)
      self
    end

    # Sets the indenter used for nested items.
    #
    # Returns self.
    def indenter(ind : Indenter) : List
      @tree.indenter(ind)
      self
    end

    # Sets the indenter from a *block*.
    #
    # Returns self.
    def indenter(&block : Tree::Children, Int32 -> String) : List
      @tree.indenter(&block)
      self
    end

    # Sets whether the list is hidden from rendering.
    #
    # Returns self.
    def hide(hidden : Bool = true) : List
      @tree.hide(hidden)
      self
    end

    # Whether the list is hidden or not.
    def hidden? : Bool
      @tree.hidden?
    end

    # The list's underlying root value. Empty for a plain list.
    def value : String
      @tree.value
    end

    # Renders the list to a string.
    def render : String
      @tree.render
    end

    # Renders the list to *io*.
    def to_s(io : IO) : Nil
      io << render
    end

    # The wrapped tree, exposed so a nested `List` can be re-parented onto this one.
    protected getter tree : Tree::Branch
  end
end
