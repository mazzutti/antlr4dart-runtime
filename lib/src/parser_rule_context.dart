part of antlr4dart;

/**
 * A rule invocation record for parsing.
 *
 * Contains all of the information about the current rule not stored
 * in the [RuleContext]. It handles parse tree children list, Any ATN
 * state tracing, and the default values available for rule indications:
 * start, stop, rule index, current alt number, current ATN state.
 *
 * Subclasses made for each rule and grammar track the parameters,
 * return values, locals, and labels specific to that rule. These
 * are the objects that are returned from rules.
 *
 */
class ParserRuleContext extends RuleContext {
  /**
   * If we are debugging or building a parse tree for a visitor,
   * we need to track all of the tokens and rule invocations associated
   * with this rule's context. This is empty for parsing w/o tree constr.
   * operation because we don't the need to track the details about
   * how we parse this rule.
   */
  List<ParseTree> children;

  Token start, stop;

  /**
   * The exception which forced this rule to return. If the rule
   * successfully completed, this is `null`.
   */
  RecognitionException exception;

  ParserRuleContext([ParserRuleContext parent, int invokingStateNumber])
  : super(parent, invokingStateNumber);

  ParserRuleContext.from(ParserRuleContext ctx) {
    parent = ctx.parent;
    invokingState = ctx.invokingState;
    start = ctx.start;
    stop = ctx.stop;
  }

  int get childCount => children != null ? children.length : 0;

  Interval get sourceInterval {
    if (start == null || stop == null) return Interval.INVALID;
    return Interval.of(start.tokenIndex, stop.tokenIndex);
  }

  /**
   * Override to make type more specific.
   */
  ParserRuleContext get parent => super.parent;

  void enterRule(ParseTreeListener listener) {}

  void exitRule(ParseTreeListener listener) {}

  /**
   * Does not set parent link; other add methods do that.
   */
  dynamic addChild(dynamic child) {
    if (child is Token) {
      child = new TerminalNode(child);
      child.parent = this;
    }
    if (children == null)
      children = new List<ParseTree>();
    children.add(child);
    return child;
  }

  /**
   * Used by `enterOuterAlt` to toss out a RuleContext previously
   * added as we entered a rule. If we have # label, we will need
   * to remove generic ruleContext object.
   */
  void removeLastChild() {
    if (children != null ) {
      children.removeLast();
    }
  }

  ErrorNode addErrorNode(Token badToken) {
    var t = new ErrorNode(badToken);
    addChild(t);
    t.parent = this;
    return t;
  }

  ParseTree getChild(int i) {
    return children != null && i >= 0
        && i < children.length ? children[i] : null;
  }

  dynamic getChildAt(Function isInstanceOf, int i) {
    if ( children==null || i < 0 || i >= children.length) {
      return null;
    }
    int j = -1; // what element have we found with ctxType?
    for (ParseTree o in children) {
      if (isInstanceOf(o)) {
        j++;
        if (j == i) return o;
      }
    }
    return null;
  }

  TerminalNode getToken(int ttype, int i) {
    if (children == null || i < 0 || i >= children.length) {
      return null;
    }
    int j = -1; // what token with ttype have we found?
    for (ParseTree o in children) {
      if (o is TerminalNode) {
        Token symbol = o.symbol;
        if (symbol.type == ttype) {
          j++;
          if (j == i) return o;
        }
      }
    }
    return null;
  }

  List<TerminalNode> getTokens(int ttype) {
    if (children == null) return <TerminalNode>[];
    List<TerminalNode> tokens = null;
    for (ParseTree o in children) {
      if (o is TerminalNode) {
        Token symbol = o.symbol;
        if (symbol.type == ttype) {
          if (tokens == null) {
            tokens = new List<TerminalNode>();
          }
          tokens.add(o);
        }
      }
    }
    if (tokens == null) return <TerminalNode>[];
    return tokens;
  }

  dynamic getRuleContext(Function isInstanceOf, int i) {
    return getChildAt(isInstanceOf, i);
  }

  List getRuleContexts(Function isInstanceOf) {
    if (children == null) return [];
    List contexts = null;
    for (ParseTree o in children) {
      if (isInstanceOf(o)) {
        if (contexts == null) {
          contexts = new List();
        }
        contexts.add(o);
      }
    }
    if (contexts == null) return [];
    return contexts;
  }

  /**
   * Used for rule context info debugging during parse-time,
   * not so much for ATN debugging.
   */
  String toInfoString(Parser recognizer) {
    List<String> rules = recognizer.getRuleInvocationStack(this);
    rules = rules.reversed;
    return "ParserRuleContext$rules{start=$start, stop=$stop}";
  }
}
