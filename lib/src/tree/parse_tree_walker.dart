part of antlr4dart;

class ParseTreeWalker {

  static final ParseTreeWalker DEFAULT = new ParseTreeWalker();

  void walk(ParseTreeListener listener, ParseTree tree) {
    if (tree is ErrorNode) {
      listener.visitErrorNode(tree);
      return;
    } else if (tree is TerminalNode) {
      listener.visitTerminal(tree);
      return;
    }
    enterRule(listener, tree);
    int n = tree.childCount;
    for (int i = 0; i < n; i++) {
      walk(listener, tree.getChild(i));
    }
    exitRule(listener, tree);
  }

  void enterRule(ParseTreeListener listener, RuleNode ruleNode) {
    ParserRuleContext context = (ruleNode as ParserRuleContext).ruleContext;
    listener.enterEveryRule(context);
    context.enterRule(listener);
  }

  void exitRule(ParseTreeListener listener, RuleNode ruleNode) {
    ParserRuleContext context = (ruleNode as ParserRuleContext).ruleContext;
    context.exitRule(listener);
    listener.exitEveryRule(context);
  }
}
