part of antlr4dart;

/// An interface to access the tree of [RuleContext] objects created
/// during a parse that makes the data structure look like a simple parse
/// tree.
/// This node represents both internal nodes, rule invocations, and leaf
/// nodes, token matches.
///
/// The payload is either a [Token] or a [RuleContext] object.
abstract class ParseTree extends SyntaxTree {

  /// The [ParseTreeVisitor] needs a double dispatch method.
  dynamic accept(ParseTreeVisitor visitor);

  /// Return the combined text of all leaf nodes. Does not get any
  /// off-channel tokens (if any) so won't return whitespace and
  /// comments if they are sent to parser on hidden channel.
  String get text;

  /// Specialize toStringTree so that it can print out more information
  /// based upon the parser.
  String toStringTree([Parser parser]);
}
