# TLDR; What functionality is in here?
# The Tree structure data model. The node hierarchy (Branch and Leaf) and its child collection.

require "./composition"
require "./style"

module Sheen
  module Tree
    # A node in a tree. A `Branch` with children, or a `Leaf` without.
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

    # A predicate-filtered, readonly view over another `Children`.
    class Filter < Children
      @predicate : (Node, Int32) -> Bool

      # Wraps *data*. Every node passes until `#filter` is set.
      def initialize(@data : Children)
        @predicate = ->(_node : Node, _index : Int32) { true }
      end

      # The filter *block* that, given the node and its index in the wrapped data, decides whether each node is kept or filtered out.
      #
      # Returns self.
      def filter(&block : Node, Int32 -> Bool) : Filter
        @predicate = block
        self
      end

      # The *index*-th passing node, or nil if out of range.
      def at(index : Int32) : Node?
        return nil if index < 0
        passing = 0
        @data.length.times do |i|
          node = @data.at(i)
          next unless node
          next unless @predicate.call(node, i)
          return node if passing == index
          passing += 1
        end
        nil
      end

      # The number of passing nodes.
      def length : Int32
        count = 0
        @data.length.times do |i|
          node = @data.at(i)
          count += 1 if node && @predicate.call(node, i)
        end
        count
      end
    end

    # Builds a detached `Children` of `Leaf` nodes out of *values*.
    #
    # Is a data source for a `Filter` or for `Branch#child`.
    def self.string_data(*values : String) : Children
      children = NodeChildren.new
      values.each { |value| children.append(Leaf.new(value)) }
      children
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

    # The mutable render configuration for a `Branch` node, containing the enumerator and indenter generators and the enumerator, item and root styles.
    class Config
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
    class Branch < Node
      getter value : String
      getter? hidden : Bool
      # This node's render configuration, or `nil` while it inherits its parent's.
      getter config : Config?

      def initialize(@value : String = "", @hidden : Bool = false)
        @children = NodeChildren.new
      end

      # Builds a tree already rooted at *value*.
      # Shorthand for `new.root(value)`
      def self.root(value) : Branch
        new.root(value)
      end

      # Sets *value* as the root and appends its children.
      #
      # Returns self.
      def root(value : Branch) : Branch
        @value = value.value
        child(value.children)
        self
      end

      # Sets *value* as the root.
      #
      # Returns self.
      def root(value) : Branch
        @value = value.to_s
        self
      end

      # Appends one or more child *values* to the tree.
      #
      # Returns self.
      def child(*values) : Branch
        values.each { |value| child(value) }
        self
      end

      # Appends a child `Branch`. A rootless *value* auto-nests onto the previous sibling, otherwise it is appended.
      #
      # Returns self.
      def child(value : Branch) : Branch
        parent, remove_at = ensure_parent(value)
        @children.remove(remove_at) if remove_at >= 0
        @children.append(parent)
        self
      end

      # Appends each node from *value* as a child.
      #
      # Returns self.
      def child(value : Children) : Branch
        value.length.times do |i|
          node = value.at(i)
          @children.append(node) if node
        end
        self
      end

      # Appends *value* as a child node.
      #
      # Returns self.
      def child(value : Node) : Branch
        @children.append(value)
        self
      end

      # Appends each element of *value* as a child.
      #
      # Returns self.
      def child(value : Array) : Branch
        value.each { |elem| child(elem) }
        self
      end

      # Skips nil, adding no child.
      #
      # Returns self.
      def child(value : Nil) : Branch
        self
      end

      # Appends *value* of any type that responds to `to_s` as a `Leaf` child.
      #
      # Returns self.
      def child(value) : Branch
        @children.append(Leaf.new(value.to_s))
        self
      end

      # Sets whether the tree is hidden from rendering.
      #
      # Returns self.
      def hide(hidden : Bool = true) : Branch
        @hidden = hidden
        self
      end

      # Renders the whole tree to a string using this node's configuration, or `Config` defaults if none have been set.
      def render : String
        Painter.new(@config || Config.new).render(self, true, "")
      end

      # Render the tree to *io*. Overrides `Node#.to_s` which emits only the bare value.
      def to_s(io : IO) : Nil
        io << render
      end

      # Sets one static *style* for every enumerator prefix.
      #
      # Returns self.
      def enumerator_style(style : Style) : Branch
        config!.enumerator_style_picker = ->(_c : Children, _i : Int32) { style }
        self
      end

      # Sets the enumerator style *block*, invoked per child.
      #
      # Returns self.
      def enumerator_style(&block : Children, Int32 -> Style) : Branch
        config!.enumerator_style_picker = block
        self
      end

      # Sets one static style for every item's value.
      #
      # Returns self.
      def item_style(style : Style) : Branch
        config!.item_style_picker = ->(_c : Children, _i : Int32) { style }
        self
      end

      # Sets the item style *block*, invoked per child for conditional styling.
      #
      # Returns self.
      def item_style(&block : Children, Int32 -> Style) : Branch
        config!.item_style_picker = block
        self
      end

      # Sets the *style* applied to the root node's value.
      #
      # Returns self.
      def root_style(style : Style) : Branch
        config!.root_style = style
        self
      end

      # Sets the branch-prefix enumerator.
      #
      # Returns self.
      def enumerator(enumr : Enumerator) : Branch
        config!.enumerator = enumr
        self
      end

      # Sets the branch-prefix enumerator from a *block*.
      #
      # Returns self.
      def enumerator(&block : Children, Int32 -> String) : Branch
        config!.enumerator = block
        self
      end

      # Sets the indenter used for nested children.
      #
      # Returns self.
      def indenter(ind : Indenter) : Branch
        config!.indenter = ind
        self
      end

      # Sets the indenter used for nested children from a *block*.
      #
      # Returns self.
      def indenter(&block : Children, Int32 -> String) : Branch
        config!.indenter = block
        self
      end

      # Lazily build and return this node's render configuration.
      private def config! : Config
        @config ||= Config.new
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

      # Auto-nest a Branch *item* and ensure that it has a parent object.
      #
      # A rootless *item* folds into the previous sibling. If sibling is a Branch, *item*'s children move into it. If it's a Leaf, *item* adops the leaf's value as its own root.
      #
      # Returns a tuple of the Branch node that should be appended and the index of a child that should first be removed (or -1 if nothing needs to be removed).
      private def ensure_parent(item : Branch) : {Branch, Int32}
        return {item, -1} if !item.value.empty? || @children.length == 0
        j = @children.length - 1
        case parent = @children.at(j)
        when Branch
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
end
