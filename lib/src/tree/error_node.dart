part of antlr4dart;

/// Represents a token that was consumed during resynchronization
/// rather than during a valid match operation. For example,
/// we will create this kind of a node during single token insertion
/// and deletion as well as during "consume until error recovery set"
/// upon no viable alternative exceptions.
class ErrorNode extends TerminalNode {
  ErrorNode(Token token) : super(token);

  dynamic accept(ParseTreeVisitor visitor) {
    return visitor.visitErrorNode(this);
  }
}
