# TLDR; What functionality is in here?
# The tree render engine. It walks the Node hierarchy and draws it, resolving each node's enumerator, indenter, and styles on a per-position basis.

require "./composition"
require "./tree"

module Sheen
  module Tree
    # Renders a `Node` to a string. A short-lived collaborator is constructed per render from the active `Config` defined.
    struct Painter
      def initialize(@config : Config)
      end

      # Renders *node* to a string.
      #
      # *root* prints the node's own value as the first line and is false while descending. *prefix is the accumulated ancestor indent prepended to every line of the subtree.
      def render(node : Node, root : Bool, prefix : String) : String
        return "" if node.hidden?

        children = node.children
        strs = [] of String

        name = node.value
        strs << @config.root_style.render(name) if root && !name.empty?

        max_len = prefix_width(children)

        i = 0
        while i < children.length
          child = children.at(i)
          render_child(strs, children, child, i, prefix, max_len) if child && !child.hidden?
          i += 1
        end

        strs.join('\n')
      end

      # First pass through. The widest styled enumerator prefix, so each node prefix can be right-padded to a common column.
      #
      # Drops a hidden *next* sibling from *children* so the last visible child still receives its last prefix.
      private def prefix_width(children : Children) : Int32
        max_len = 0
        i = 0
        while i < children.length
          if i < children.length - 1
            nxt = children.at(i + 1)
            children.as(NodeChildren).remove(i + 1) if nxt && nxt.hidden?
          end
          styled = @config.enumerator_style_picker.call(children, i)
            .render(@config.enumerator.call(children, i))
          max_len = {Sheen.width(styled), max_len}.max
          i += 1
        end
        max_len
      end

      # Second pass through. Appends the child's own row, then renders its subtree underneath.
      #
      # Switches to the child's own config when it has one.
      private def render_child(strs : Array(String), children : Children,
                               child : Node, i : Int32, prefix : String,
                               max_len : Int32) : Nil
        indent = @config.indenter.call(children, i)
        enum_style = @config.enumerator_style_picker.call(children, i)
        item_style = @config.item_style_picker.call(children, i)

        node_prefix = enum_style.render(@config.enumerator.call(children, i))
        gap = max_len - Sheen.width(node_prefix)
        node_prefix = (" " * gap) + node_prefix if gap > 0

        item = item_style.render(child.value)
        multiline_prefix = prefix

        # Reconcile heights so a multiline item keeps columns aligned. First grow the node prefix with styled indents so each item gets a continuation glyph.
        while Sheen.height(item) > Sheen.height(node_prefix)
          node_prefix = Sheen.join_vertical(Position::LEFT, node_prefix, enum_style.render(indent))
        end
        # THEN grow the ancestor prefix so every item also carries the ancestor's indent.
        while Sheen.height(node_prefix) > Sheen.height(multiline_prefix)
          multiline_prefix = Sheen.join_vertical(Position::LEFT, multiline_prefix, prefix)
        end

        strs << Sheen.join_horizontal(Position::TOP, multiline_prefix, node_prefix, item)

        # Descend. A child Branch with its own config overrides ours for it subtree.
        sub_painter = self
        if child.is_a?(Branch) && (child_config = child.config)
          sub_painter = Painter.new(child_config)
        end
        sub = sub_painter.render(child, false, prefix + enum_style.render(indent))
        strs << sub unless sub.empty?
      end
    end
  end
end
