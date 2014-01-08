part of antlr4dart;

class ParseTreeWalker {

  static final ParseTreeWalker DEFAULT = new ParseTreeWalker();

  void walk(ParseTreeListener listener, ParseTree t) {
    if (t is ErrorNode) {
      listener.visitErrorNode(t);
      return;
    } else if (t is TerminalNode) {
      listener.visitTerminal(t);
      return;
    }
    enterRule(listener, t);
    int n = t.childCount;
    for (int i = 0; i<n; i++) {
      walk(listener, t.getChild(i));
    }
    exitRule(listener, t);
  }

  /**
   * The discovery of a rule node, involves sending two events: the generic
   * [ParseTreeListener.enterEveryRule] and a [RuleContext]-specific event.
   * First we trigger the generic and then the rule specific. We to them
   * in reverse order upon finishing the node.
   */
  void enterRule(ParseTreeListener listener, RuleNode r) {
    ParserRuleContext ctx = (r as ParserRuleContext).ruleContext;
    listener.enterEveryRule(ctx);
    ctx.enterRule(listener);
  }

  void exitRule(ParseTreeListener listener, RuleNode r) {
    ParserRuleContext ctx = (r as ParserRuleContext).ruleContext;
    ctx.exitRule(listener);
    listener.exitEveryRule(ctx);
  }
}
