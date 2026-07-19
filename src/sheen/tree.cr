# TLDR; What functionality is in here?
# The Tree structure data model. The node hierarchy (Tree and Leaf) and its child collection.

require "./composition"

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

  # A node in a tree.
  #
  # An implementation of Node with children and a builder API.
  class Tree < Node
    getter value : String
    getter? hidden : Bool

    def initialize(@value : String = "", @hidden : Bool = false)
      @children = NodeChildren.new
    end

    # Builds a tree already rooted at *value*.
    # Shorthand for `new.root(value)`
    def self.root(value) : Tree
      new.root(value)
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
