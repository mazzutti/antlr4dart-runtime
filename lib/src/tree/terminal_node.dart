part of antlr4dart;

class TerminalNode implements ParseTree {
  Token symbol;
  ParseTree parent;

  TerminalNode(this.symbol);

  ParseTree getChild(int i) => null;

  Token get payload => symbol;

  Interval get sourceInterval {
    if (symbol == null) return Interval.INVALID;
    int tokenIndex = symbol.tokenIndex;
    return new Interval(tokenIndex, tokenIndex);
  }

  int get childCount => 0;

  dynamic accept(ParseTreeVisitor visitor) {
    return visitor.visitTerminal(this);
  }

  String get text => symbol.text;

  String toStringTree([Parser parser]) {
    return toString();
  }

  String toString() {
    if (symbol.type == Token.EOF) return "<EOF>";
    return symbol.text;
  }
}
