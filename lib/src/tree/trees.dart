part of antlr4dart;

/// A set of utility routines useful for all kinds of antlr4dart trees.
class Trees {

  /// Print out a whole tree in LISP form. [getNodeText] is used on the
  /// node payloads to get the text for the nodes. Detect parse trees and
  /// extract data appropriately.
  static String toStringTree(Tree tree, [dynamic rules]) {
    if (rules is Parser) rules = rules.ruleNames;
    String s = getNodeText(tree, rules).replaceAll("\t", "\\t");
    s = s.replaceAll("\n", "\\n");
    s = s.replaceAll("\r", "\\r");
    if (tree.childCount == 0) return s;
    StringBuffer sb = new StringBuffer("(")
        ..write(s)
        ..write(' ');
    for (int i = 0; i < tree.childCount; i++) {
      if (i > 0) sb.write(' ');
      sb.write(toStringTree(tree.getChild(i), rules));
    }
    sb.write(")");
    return sb.toString();
  }

  static String getNodeText(Tree tree, dynamic rules) {
    if (rules is Parser) rules = rules.ruleNames;
    if (rules != null) {
      if (tree is RuleNode) {
        return rules[tree.ruleContext.ruleIndex];
      } else if (tree is ErrorNode) {
        return tree.toString();
      } else if (tree is TerminalNode) {
        Token symbol = tree.symbol;
        if (symbol != null) return symbol.text;
      }
    }
    // no recog for rule names
    Object payload = tree.payload;
    if (payload is Token) return payload.text;
    return payload.toString();
  }

  /// Return a list of all ancestors of this node.  The first node of
  /// list is the root and the last is the parent of this node.
  static List<Tree> getAncestors(Tree tree) {
    if (tree.parent == null) return <Tree>[];
    List<Tree> ancestors = new List<Tree>();
    tree = tree.parent;
    while (tree != null) {
      ancestors.insert(0, tree); // insert at start
      tree = tree.parent;
    }
    return ancestors;
  }

  Trees._internal() {}
}
