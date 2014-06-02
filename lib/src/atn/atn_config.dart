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
      : this.semanticContext = (semanticContext != null)
          ? semanticContext : SemanticContext.NONE,
        this.state = state,
        this.alt = alt,
        this.context = context;

  AtnConfig.from(AtnConfig c,
                 {AtnState state,
                 PredictionContext context,
                 SemanticContext semanticContext})
      : this.state = (state != null) ? state : c.state,
        this.context = (context != null) ? context : c.context,
        this.semanticContext = (semanticContext != null)
            ? semanticContext : c.semanticContext,
        alt = c.alt,
        reachesIntoOuterContext = c.reachesIntoOuterContext;

  /// An ATN configuration is equal to [other] if both have the same state,
  /// they predict the same alternative, and syntactic/semantic contexts are
  /// the same.
  bool operator==(Object other) {
    return other is AtnConfig
        && state.stateNumber == other.state.stateNumber
        && alt == other.alt
        && (context == other.context
           || context != null && context == other.context)
        && semanticContext == other.semanticContext;
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
    StringBuffer sb = new StringBuffer('(')..write(state);
    if (showAlt) sb.write(",$alt");
    if (context != null) sb.write(",[$context]");
    if (semanticContext != null && semanticContext != SemanticContext.NONE) {
      sb.write(",$semanticContext");
    }
    if (reachesIntoOuterContext > 0) {
      sb.write(",up=$reachesIntoOuterContext");
    }
    sb.write(')');
    return sb.toString();
  }
}

class LexerAtnConfig extends AtnConfig {

  /// Capture lexer actions we traverse.
  final LexerActionExecutor lexerActionExecutor;

  final bool hasPassedThroughNonGreedyDecision;

  LexerAtnConfig(AtnState state,
                 int alt,
                 PredictionContext context,
                 [this.lexerActionExecutor])
    : hasPassedThroughNonGreedyDecision = false,
      super(state, alt, context, SemanticContext.NONE);


  LexerAtnConfig.from(LexerAtnConfig c,
                      AtnState state,
                      {LexerActionExecutor actionExecutor,
                      PredictionContext context})
    : lexerActionExecutor = (actionExecutor != null)
        ? actionExecutor : c.lexerActionExecutor,
      hasPassedThroughNonGreedyDecision = c.hasPassedThroughNonGreedyDecision
        || state is DecisionState && state.nonGreedy,
      super.from(c, state:state, context:(context != null) ? context: c.context,
        semanticContext:c.semanticContext);

  int get hashCode {
    int hashCode = MurmurHash.initialize(7);
    hashCode = MurmurHash.update(hashCode, state.stateNumber);
    hashCode = MurmurHash.update(hashCode, alt);
    hashCode = MurmurHash.update(hashCode, context.hashCode);
    hashCode = MurmurHash.update(hashCode, semanticContext.hashCode);
    hashCode = MurmurHash.update(hashCode,
        hasPassedThroughNonGreedyDecision ? 1 : 0);
    hashCode = MurmurHash.update(hashCode, lexerActionExecutor.hashCode);
    hashCode = MurmurHash.finish(hashCode, 6);
    return hashCode;
  }

  bool operator==(AtnConfig other) {
    return other is  LexerAtnConfig
        && hasPassedThroughNonGreedyDecision
            == other.hasPassedThroughNonGreedyDecision
        && lexerActionExecutor == other.lexerActionExecutor
        && super == other;
  }
}

