part of antlr4dart;

/// A rule context is a record of a single rule invocation. It knows
/// which context invoked it, if any. If there is no parent context, then
/// naturally the invoking state is not valid.  The parent link
/// provides a chain upwards from the current rule invocation to the root
/// of the invocation tree, forming a stack. We actually carry no
/// information about the rule associated with this context (except
/// when parsing). We keep only the state number of the invoking state from
/// the ATN submachine that invoked this. Contrast this with the s
/// pointer inside [ParserRuleContext] that tracks the current state
/// being "executed" for the current rule.
///
/// The parent contexts are useful for computing lookahead sets and
/// getting error information.
///
/// These objects are used during parsing and prediction.
/// For the special case of parsers and tree parsers, we use the subclass
/// [ParserRuleContext].
///
class RuleContext implements RuleNode {

  static final ParserRuleContext EMPTY = new ParserRuleContext();

  /// What context invoked this rule?
  RuleContext parent;

  /// What state invoked the rule associated with this context?
  /// The "return address" is the `followState` of `invokingState`
  /// If parent is `null`, this should be `-1`.
  int invokingState = -1;

  RuleContext([this.parent, this.invokingState = -1]);

  /// A context is empty if there is no invoking state; meaning
  /// nobody call current context.
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
    StringBuffer buf = new StringBuffer();
    for (int i = 0; i < childCount; i++) {
      buf.write(getChild(i).text);
    }
    return buf.toString();
  }

  int get ruleIndex => -1;

  int get childCount => 0;

  int depth() {
    int n = 0;
    RuleContext p = this;
    while (p != null) {
      p = p.parent;
      n++;
    }
    return n;
  }

  ParseTree getChild(int i) => null;

  dynamic accept(ParseTreeVisitor visitor) {
    return visitor.visitChildren(this);
  }

  /// Print out a whole tree, not just a node, in LISP format
  /// (root child1 .. childN). Print just a node if this is a leaf.
  /// [rules] could be a [Recognizer] or a List of rule names.
  String toStringTree([rules]) {
    return Trees.toStringTree(this, rules);
  }

  String toString([rules, RuleContext stop]) {
    stop = (stop != null) ? stop : RuleContext.EMPTY;
    List<String> ruleNames = (rules is Recognizer) ? rules.ruleNames : null;
    StringBuffer buf = new StringBuffer("[");
    RuleContext p = this;
    while (p != null && p != stop) {
      if (ruleNames == null) {
        if (!p.isEmpty) buf.write(p.invokingState);
      } else {
        int ruleIndex = p.ruleIndex;
        if (ruleIndex >= 0 && ruleIndex < ruleNames.length) {
          buf.write(ruleNames[ruleIndex]);
        } else {
          buf.write(ruleIndex);
        }
      }
      if (p.parent != null
          && (ruleNames != null || !p.parent.isEmpty)) {
        buf.write(" ");
      }
      p = p.parent;
    }
    buf.write("]");
    return buf.toString();
  }
}
