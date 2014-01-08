part of antlr4dart;

/**
 * A tree that knows about an interval in a token source
 * is some kind of syntax tree. Subinterfaces distinguish
 * between parse trees and other kinds of syntax trees we
 * might want to create.
 */
abstract class SyntaxTree extends Tree {
  /**
   * Return an [Interval] indicating the index in the [TokenSource] of the
   * first and last token associated with this subtree. If this node is a
   * leaf, then the interval represents a single token.
   *
   * If source interval is unknown, this returns [Interval.INVALID].
   */
  Interval get sourceInterval;
}
