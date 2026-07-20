# TLDR; What functionality is in here?
# The Tree structure data model. The node hierarchy (Tree and Leaf) and its child collection.

require "./composition"
require "./style"

module Sheen
  # A node in a tree. A `Tree` with children, or a `Leaf` without.
  abstract class Node
    # The node's display value.
    abstract def value : String
    # The node's children, empty for a `Leaf`.
    abstract def children : Children
    # If this node is hidden from rendering or not.
    abstract def hidden? : Bool

    # Renders the node as its value.
    def to_s(io : IO) : Nil
      io << value
    end
  end

  # A readonly view over a node's children.
  abstract class Children
    # The node at *index*, or nil when out of range.
    abstract def at(index : Int32) : Node?
    # The number of children.
    abstract def length : Int32
  end

  # A readonly view over a node's children.
  #
  # A mutable, array-backed implementation of `Children`.
  class NodeChildren < Children
    def initialize(@nodes : Array(Node) = [] of Node)
    end

    # Appends *node* to the `NodeChildren` self.
    def append(node : Node) : NodeChildren
      @nodes << node
      self
    end

    # Removes the node at *index*. Out of range indices are ignored.
    #
    # Returns self.
    def remove(index : Int32) : NodeChildren
      return self if index < 0 || index >= @nodes.size
      @nodes.delete_at(index)
      self
    end

    # The node at *index*, or nil when out of range.
    def at(index : Int32) : Node?
      return nil if index < 0
      @nodes[index]?
    end

    # The number of children.
    def length : Int32
      @nodes.size
    end
  end

  # A node in a tree.
  #
  # A childless implementation of Node whose value is the string it was built from.
  class Leaf < Node
    getter value : String
    getter? hidden : Bool

    def initialize(@value : String, @hidden : Bool = false)
    end

    # A leaf by definition has no children
    def children : Children
      NodeChildren.new
    end
  end

  # A branch-prefix generator. Given a node's `Children` and a child index, return the enumerator string drawn before that child (eg "|--").
  alias Enumerator = Children, Int32 -> String

  # An indent generator. Given a node's `Children` and a child index, return the indent drawn before that child's descendants (eg "|  ").
  alias Indenter = Children, Int32 -> String

  # A per-position style selector enabling conditional styling. Given a node's `Children` and a child's index, return the `Style` for that position.
  alias StylePicker = Children, Int32 -> Style

  # The mutable render configuration for a `Tree` node, containing the enumerator and indenter generators and the enumerator, item and root styles.
  class TreeStyle
    # The branch-prefix generator.
    property enumerator : Enumerator
    # The indent generator.
    property indenter : Indenter
    # Selects the style applied to each enumerator prefix.
    property enumerator_style_picker : StylePicker
    # Selects the style applied to each item's value.
    property item_style_picker : StylePicker
    # The style applied to the root node's value.
    property root_style : Style

    def initialize(
      @enumerator = ->Tree.default_enumerator(Children, Int32),
      @indenter = ->Tree.default_indenter(Children, Int32),
      # Trailing padding space separates the branch prefix from the item at render time.
      @enumerator_style_picker = ->(_c : Children, _i : Int32) { Style.new.padding_right(1) },
      @item_style_picker = ->(_c : Children, _i : Int32) { Style.new },
      @root_style = Style.new,
    )
    end
  end

  # A node in a tree.
  #
  # An implementation of Node with children and a builder API.
  class Tree < Node
    getter value : String
    getter? hidden : Bool
    # This node's render configuration, or `nil` while it inherits its parent's.
    getter config : TreeStyle?

    def initialize(@value : String = "", @hidden : Bool = false)
      @children = NodeChildren.new
    end

    # Builds a tree already rooted at *value*.
    # Shorthand for `new.root(value)`
    def self.root(value) : Tree
      new.root(value)
    end

    # Default branch enumerator symbol.
    def self.default_enumerator(children : Children, index : Int32) : String
      children.length - 1 == index ? "└──" : "├──"
    end

    # A branch enumerator symbol with a rounded corner for the last child.
    def self.rounded_enumerator(children : Children, index : Int32) : String
      children.length - 1 == index ? "╰──" : "├──"
    end

    # The default indenter (three spaces).
    def self.default_indenter(children : Children, index : Int32) : String
      children.length - 1 == index ? "   " : "│  "
    end

    # Sets *value* as the root and appends its children.
    #
    # Returns self.
    def root(value : Tree) : Tree
      @value = value.value
      child(value.children)
      self
    end

    # Sets *value* as the root.
    #
    # Returns self.
    def root(value) : Tree
      @value = value.to_s
      self
    end

    # Appends one or more child *values* to the tree.
    #
    # Returns self.
    def child(*values) : Tree
      values.each { |value| child(value) }
      self
    end

    # Appends a child `Tree`. A rootless *value* auto-nests onto the previous sibling, otherwise it is appended.
    #
    # Returns self.
    def child(value : Tree) : Tree
      parent, remove_at = ensure_parent(value)
      @children.remove(remove_at) if remove_at >= 0
      @children.append(parent)
      self
    end

    # Appends each node from *value* as a child.
    #
    # Returns self.
    def child(value : Children) : Tree
      value.length.times do |i|
        node = value.at(i)
        @children.append(node) if node
      end
      self
    end

    # Appends *value* as a child node.
    #
    # Returns self.
    def child(value : Node) : Tree
      @children.append(value)
      self
    end

    # Appends each element of *value* as a child.
    #
    # Returns self.
    def child(value : Array) : Tree
      value.each { |elem| child(elem) }
      self
    end

    # Skips nil, adding no child.
    #
    # Returns self.
    def child(value : Nil) : Tree
      self
    end

    # Appends *value* of any type that responds to `to_s` as a `Leaf` child.
    #
    # Returns self.
    def child(value) : Tree
      @children.append(Leaf.new(value.to_s))
      self
    end

    # Sets whether the tree is hidden from rendering.
    #
    # Returns self.
    def hide(hidden : Bool = true) : Tree
      @hidden = hidden
      self
    end

    # Sets one static *style* for every enumerator prefix.
    #
    # Returns self.
    def enumerator_style(style : Style) : Tree
      config!.enumerator_style_picker = ->(_c : Children, _i : Int32) { style }
      self
    end

    # Sets the enumerator style *block*, invoked per child.
    #
    # Returns self.
    def enumerator_style(&block : Children, Int32 -> Style) : Tree
      config!.enumerator_style_picker = block
      self
    end

    # Sets one static style for every item's value.
    #
    # Returns self.
    def item_style(style : Style) : Tree
      config!.item_style_picker = ->(_c : Children, _i : Int32) { style }
      self
    end

    # Sets the item style *block*, invoked per child for conditional styling.
    #
    # Returns self.
    def item_style(&block : Children, Int32 -> Style) : Tree
      config!.item_style_picker = block
      self
    end

    # Sets the *style* applied to the root node's value.
    #
    # Returns self.
    def root_style(style : Style) : Tree
      config!.root_style = style
      self
    end

    # Sets the branch-prefix enumerator.
    #
    # Returns self.
    def enumerator(enumr : Enumerator) : Tree
      config!.enumerator = enumr
      self
    end

    # Sets the branch-prefix enumerator from a *block*.
    #
    # Returns self.
    def enumerator(&block : Children, Int32 -> String) : Tree
      config!.enumerator = block
      self
    end

    # Sets the indenter used for nested children.
    #
    # Returns self.
    def indenter(ind : Indenter) : Tree
      config!.indenter = ind
      self
    end

    # Sets the indenter used for nested children from a *block*.
    #
    # Returns self.
    def indenter(&block : Children, Int32 -> String) : Tree
      config!.indenter = block
      self
    end

    # Lazily build and return this node's render configuration.
    private def config! : TreeStyle
      @config ||= TreeStyle.new
    end

    # A copy of the tree's children.
    def children : Children
      copy = NodeChildren.new
      @children.length.times do |i|
        node = @children.at(i)
        copy.append(node) if node
      end
      copy
    end

    # Auto-nest a Tree *item* and ensure that it has a parent object.
    #
    # A rootless *item* folds into the previous sibling. If sibling is a Tree, *item*'s children move into it. If it's a Leaf, *item* adops the leaf's value as its own root.
    #
    # Returns a tuple of the Tree node that should be appended and the index of a child that should first be removed (or -1 if nothing needs to be removed).
    private def ensure_parent(item : Tree) : {Tree, Int32}
      return {item, -1} if !item.value.empty? || @children.length == 0
      j = @children.length - 1
      case parent = @children.at(j)
      when Tree
        kids = item.children
        kids.length.times do |i|
          if kid = kids.at(i)
            parent.child(kid)
          end
        end
        {parent, j}
      when Leaf
        item.root(parent.value)
        {item, j}
      else
        {item, -1}
      end
    end
  end
end
