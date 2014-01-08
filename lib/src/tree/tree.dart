part of antlr4dart;

/**
 * The basic notion of a tree has a parent, a payload, and a list of children.
 * It is the most abstract interface for all the trees used by antlr4dart.
 */
abstract class Tree {
  /**
   * The parent of this node. If the return value is null, then this
   * node is the root of the tree.
   */
  Tree get parent;

  /**
   * This method returns whatever object represents the data at this note. For
   * example, for parse trees, the payload can be a [Token] representing
   * a leaf node or a [RuleContext] object representing a rule invocation.
   * For abstract syntax trees (ASTs), this is a [Token] object.
   */
  Object get payload;

  /**
   * How many children are there? If there is none, then this
   * node represents a leaf node.
   */
  int get childCount;

  /**
   * If there are children, get the `i`th value indexed from `0`.
   */
  Tree getChild(int i);

  /**
   * Print out a whole tree, not just a node, in LISP format
   * `(root child1 .. childN)`. Print just a node if this is a leaf.
   */
  String toStringTree();
}
