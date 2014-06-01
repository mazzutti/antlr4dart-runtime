part of antlr4dart;

/// A set of utility routines useful for all kinds of antlr4dart trees.
class Trees {

  /// Print out a whole tree in LISP form. [getNodeText] is used on the
  /// node payloads to get the text for the nodes. Detect parse trees and
  /// extract data appropriately.
  static String toStringTree(Tree t, [dynamic rules]) {
    if (rules is Parser) rules = rules.ruleNames;
    String s = getNodeText(t, rules);
    s.replaceAll("\t", "\\t");
    s.replaceAll("\n", "\\n");
    s.replaceAll("\r", "\\r");
    if (t.childCount == 0) return s;
    StringBuffer buf = new StringBuffer("(");
    buf.write(s);
    buf.write(' ');
    for (int i = 0; i < t.childCount; i++) {
      if (i > 0) buf.write(' ');
      buf.write(toStringTree(t.getChild(i), rules));
    }
    buf.write(")");
    return buf.toString();
  }

  static String getNodeText(Tree t, dynamic rules) {
    if (rules is Parser) rules = rules.ruleNames;
    if (rules != null) {
      if (t is RuleNode) {
        int ruleIndex = t.ruleContext.ruleIndex;
        String ruleName = rules[ruleIndex];
        return ruleName;
      } else if (t is ErrorNode) {
        return t.toString();
      } else if (t is TerminalNode) {
        Token symbol = t.symbol;
        if (symbol != null) {
          String s = symbol.text;
          return s;
        }
      }
    }
    // no recog for rule names
    Object payload = t.payload;
    if ( payload is Token ) {
      return payload.text;
    }
    return t.payload.toString();
  }

  /// Return a list of all ancestors of this node.  The first node of
  /// list is the root and the last is the parent of this node.
  static List<Tree> getAncestors(Tree t) {
    if (t.parent == null) return <Tree>[];
    List<Tree> ancestors = new List<Tree>();
    t = t.parent;
    while (t != null) {
      ancestors.insert(0, t); // insert at start
      t = t.parent;
    }
    return ancestors;
  }

  Trees._internal() {}
}
