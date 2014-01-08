part of antlr4dart;

abstract class ParseTreeListener {
  void visitTerminal(TerminalNode node);
  void visitErrorNode(ErrorNode node);
  void enterEveryRule(ParserRuleContext ctx);
  void exitEveryRule(ParserRuleContext ctx);
}
