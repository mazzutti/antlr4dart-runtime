part of antlr4dart;

/// A tuple: (ATN state, predicted alt, syntactic, semantic context).
/// The syntactic context is a graph-structured stack node whose
/// path(s) to the root is the rule invocation(s)
/// chain used to arrive at the state.  The semantic context is
/// the tree of semantic predicates encountered before reaching
/// an ATN state.
class AtnConfig {
  /// The ATN state associated with this configuration
  final AtnState state;

  /// What alt (or lexer rule) is predicted by this configuration
  final int alt;

  /// The stack of invoking states leading to the rule/states associated
  /// with this config.  We track only those contexts pushed during
  /// execution of the ATN simulator.
  PredictionContext context;

  /// We cannot execute predicates dependent upon local context unless
  /// we know for sure we are in the correct context. Because there is
  /// no way to do this efficiently, we simply cannot evaluate
  /// dependent predicates unless we are in the rule that initially
  /// invokes the ATN simulator.
  int reachesIntoOuterContext = 0;

  final SemanticContext semanticContext;

  AtnConfig(AtnState state,
           int alt,
           PredictionContext context,
           [SemanticContext semanticContext])
      : semanticContext = (semanticContext != null)
          ? semanticContext : SemanticContext.NONE,
        state = state,
        alt = alt,
        context = context;

  AtnConfig.from(AtnConfig c,
                 {AtnState state,
                 PredictionContext context,
                 SemanticContext semanticContext})
      : state = (state != null) ? state : c.state,
        context = (context != null) ? context : c.context,
        semanticContext = (semanticContext != null) ? semanticContext : c.semanticContext,
        alt = c.alt,
        reachesIntoOuterContext = c.reachesIntoOuterContext;

  /// An ATN configuration is equal to another if both have
  /// the same state, they predict the same alternative, and
  /// syntactic/semantic contexts are the same.
  bool operator==(Object o) {
    if (o is AtnConfig) {
      return state.stateNumber == o.state.stateNumber
        && alt == o.alt
        && (context == o.context || (context != null && context == o.context))
        && semanticContext == o.semanticContext;
    }
    return false;
  }

  int get hashCode {
    int hashCode = MurmurHash.initialize(7);
    hashCode = MurmurHash.update(hashCode, state.stateNumber);
    hashCode = MurmurHash.update(hashCode, alt);
    hashCode = MurmurHash.update(hashCode, context.hashCode);
    hashCode = MurmurHash.update(hashCode, semanticContext.hashCode);
    hashCode = MurmurHash.finish(hashCode, 4);
    return hashCode;
  }

  String toString([Recognizer recog, bool showAlt = true]) {
    StringBuffer buf = new StringBuffer('(')
      ..write(state);
    if (showAlt) buf.write(",$alt");
    if (context!=null) buf.write(",[$context]");
    if (semanticContext != null && semanticContext != SemanticContext.NONE) {
      buf.write(",$semanticContext");
    }
    if (reachesIntoOuterContext > 0) {
      buf.write(",up=$reachesIntoOuterContext");
    }
    buf.write(')');
    return buf.toString();
  }
}
