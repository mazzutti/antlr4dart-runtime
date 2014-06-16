part of antlr4dart;

typedef bool IsInstanceOf(RuleContext context);

/// A rule context is a record of a single rule invocation. It knows which
/// context invoked it, if any. If there is no parent context, the naturally
/// the invoking state is not valid. The parent link provides a chain upwards
/// from the current rule invocation to the root of the invocation tree,
/// forming a stack. We actually carry no information about the rule associated
/// with this context (except when parsing).
///
/// The parent contexts are useful for computing lookahead sets and getting
/// error information.
///
/// These objects are used during parsing and prediction. For the special case
/// of parsers and tree parsers, we use the subclass [ParserRuleContext].
///
class RuleContext implements RuleNode {

  static final ParserRuleContext EMPTY = new ParserRuleContext();

  /// What context invoked this rule?
  RuleContext parent;

  /// What state invoked the rule associated with this context?
  ///
  /// If parent is `null`, this should be `-1`.
  int invokingState = -1;

  RuleContext([this.parent, this.invokingState = -1]);

  /// A context is empty if there is no invoking state; meaning nobody call
  /// current context.
  bool get isEmpty => invokingState == -1;

  Interval get sourceInterval => Interval.INVALID;

  RuleContext get ruleContext => this;

  RuleContext get payload => this;

  /// Return the combined text of all child nodes. This method only considers
  /// tokens which have been added to the parse tree.
  ///
  /// Since tokens on hidden channels (e.g. whitespace or comments) are not
  /// added to the parse trees, they will not appear in the output of this
  /// method.
  String get text {
    if (childCount == 0) return "";
    StringBuffer sb = new StringBuffer();
    for (int i = 0; i < childCount; i++) {
      sb.write(getChild(i).text);
    }
    return sb.toString();
  }

  int get ruleIndex => -1;

  int get childCount => 0;

  int depth() {
    int depth = 0;
    RuleContext parent = this;
    while (parent != null) {
      parent = parent.parent;
      depth++;
    }
    return depth;
  }

  ParseTree getChild(int i) => null;

  dynamic accept(ParseTreeVisitor visitor) => visitor.visitChildren(this);

  /// If [asTree] is `true`, return a whole string tree, not just a node,
  /// in LISP format (root `child1..childN`) or just a node when this is
  /// a leaf. Otherwise, return a string representation this [RuleContext]
  /// surrounded by `[]`.
  ///
  /// [sourceOfRules] could be a [Recognizer] or a [List] of rule names.
  String toString([Recognizer sourceOfRules, bool asTree = true]) {
    return (sourceOfRules != null && asTree)
        ? Trees.toStringTree(this, sourceOfRules)
        : _toString(sourceOfRules);
  }

  String _toString([sourceOfRules, RuleContext stop]) {
    stop = (stop != null) ? stop : RuleContext.EMPTY;
    List<String> ruleNames = (sourceOfRules is Recognizer)
        ? sourceOfRules.ruleNames
        : null;
    StringBuffer sb = new StringBuffer("[");
    RuleContext parent = this;
    while (parent != null && parent != stop) {
      if (ruleNames == null) {
        if (!parent.isEmpty) sb.write(parent.invokingState);
      } else {
        int ruleIndex = parent.ruleIndex;
        if (ruleIndex >= 0 && ruleIndex < ruleNames.length) {
          sb.write(ruleNames[ruleIndex]);
        } else {
          sb.write(ruleIndex);
        }
      }
      if (parent.parent != null
          && (ruleNames != null || !parent.parent.isEmpty)) {
        sb.write(" ");
      }
      parent = parent.parent;
    }
    sb.write("]");
    return sb.toString();
  }
}

/// This object is used by the [ParserInterpreter] and is the same as a regular
/// [ParserRuleContext] except that we need to track the rule index of the
/// current context so that we can build parse trees.
class InterpreterRuleContext extends ParserRuleContext {
  final int ruleIndex;

  InterpreterRuleContext(ParserRuleContext parent,
                         int invokingStateNumber,
                         this.ruleIndex) : super(parent, invokingStateNumber);

}

/// A rule invocation record for parsing.
///
/// Contains all of the information about the current rule not stored in the
/// [RuleContext]. It handles parse tree children list, Any ATN state tracing,
/// and the default values available for rule indications: start, stop, rule
/// index, current alt number, current ATN state.
///
/// Subclasses made for each rule and grammar track the parameters, return
/// values, locals, and labels specific to that rule. These are the objects
/// that are returned from rules.
///
class ParserRuleContext extends RuleContext {

  /// If we are debugging or building a parse tree for a visitor, we need to
  /// track all of the tokens and rule invocations associated with this rule's
  /// context.
  ///
  /// This is empty for parsing w/o tree constr. operation because we don't
  /// the need to track the details about how we parse this rule.
  List<ParseTree> children;

  Token start, stop;

  /// The exception which forced this rule to return. If the rule
  /// successfully completed, this is `null`.
  RecognitionException exception;

  ParserRuleContext([ParserRuleContext parent, int invokingStateNumber])
      : super(parent, invokingStateNumber);

  ParserRuleContext.from(ParserRuleContext context) {
    parent = context.parent;
    invokingState = context.invokingState;
    start = context.start;
    stop = context.stop;
  }

  int get childCount => children != null ? children.length : 0;

  Interval get sourceInterval {
    return (start == null || stop == null)
        ? Interval.INVALID
        : Interval.of(start.tokenIndex, stop.tokenIndex);
  }

  void enterRule(ParseTreeListener listener) {}

  void exitRule(ParseTreeListener listener) {}

  /// Does not set parent link; other add methods do that.
  dynamic addChild(dynamic child) {
    if (child is Token) {
      child = new TerminalNode(child);
      child.parent = this;
    }
    if (children == null) children = new List<ParseTree>();
    children.add(child);
    return child;
  }

  /// Used by [Parser.enterOuterAlt] to toss out a [RuleContext] previously
  /// added as we entered a rule. If we have # label, we will need to remove
  /// generic rule context object.
  void removeLastChild() {
    if (children != null ) {
      children.removeLast();
    }
  }

  ErrorNode addErrorNode(Token badToken) {
    var node = new ErrorNode(badToken);
    addChild(node);
    node.parent = this;
    return node;
  }

  ParseTree getChild(int i) {
    return children != null && i >= 0
        && i < children.length ? children[i] : null;
  }

  dynamic getChildAt(IsInstanceOf isInstanceOf, int i) {
    if (children == null || i < 0 || i >= children.length) return null;
    int pos = -1; // what element have we found with ctxType?
    for (ParseTree child in children) {
      if (isInstanceOf(child)) {
        pos++;
        if (pos == i) return child;
      }
    }
    return null;
  }

  TerminalNode getToken(int ttype, int i) {
    if (children == null || i < 0 || i >= children.length) return null;
    int pos = -1; // what token with ttype have we found?
    for (ParseTree child in children) {
      if (child is TerminalNode) {
        Token symbol = child.symbol;
        if (symbol.type == ttype) {
          pos++;
          if (pos == i) return child;
        }
      }
    }
    return null;
  }

  List<TerminalNode> getTokens(int ttype) {
    if (children == null) return <TerminalNode>[];
    List<TerminalNode> tokens = null;
    for (ParseTree child in children) {
      if (child is TerminalNode) {
        Token symbol = child.symbol;
        if (symbol.type == ttype) {
          if (tokens == null) {
            tokens = new List<TerminalNode>();
          }
          tokens.add(child);
        }
      }
    }
    return tokens == null ? <TerminalNode>[] : tokens;
  }

  dynamic getRuleContext(IsInstanceOf isInstanceOf, int i) {
    return getChildAt(isInstanceOf, i);
  }

  List getRuleContexts(IsInstanceOf isInstanceOf) {
    if (children == null) return [];
    List contexts = null;
    for (ParseTree child in children) {
      if (isInstanceOf(child)) {
        if (contexts == null) {
          contexts = new List();
        }
        contexts.add(child);
      }
    }
    return contexts == null ? [] : contexts;
  }

  // Used for rule context info debugging during parse-time, not so much
  // for ATN debugging.
  String _toInfoString(Parser recognizer) {
    List<String> rules = recognizer.getRuleInvocationStack(this);
    rules = rules.reversed;
    return "ParserRuleContext$rules{start=$start, stop=$stop}";
  }
}

