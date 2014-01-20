part of antlr4dart;

class LexerAtnConfig extends AtnConfig {

  /**
   * Capture lexer actions we traverse.
   */
  LexerActionExecutor lexerActionExecutor;

  final bool hasPassedThroughNonGreedyDecision;

  LexerAtnConfig(AtnState state,
                 int alt,
                 PredictionContext context,
                 [this.lexerActionExecutor])
    : super(state, alt, context, SemanticContext.NONE),
      hasPassedThroughNonGreedyDecision = false;

  LexerAtnConfig.from(LexerAtnConfig c,
                      AtnState state,
                      {LexerActionExecutor actionExecutor,
                      PredictionContext context})
    : super.from(c, state:state,
                 context:(context != null) ? context: c.context,
                 semanticContext:c.semanticContext),
      hasPassedThroughNonGreedyDecision =
        c.hasPassedThroughNonGreedyDecision || state is DecisionState && state.nonGreedy {
    lexerActionExecutor = (actionExecutor != null) ? actionExecutor : c.lexerActionExecutor;
  }

  int get hashCode {
    int hashCode = MurmurHash.initialize(7);
    hashCode = MurmurHash.update(hashCode, state.stateNumber);
    hashCode = MurmurHash.update(hashCode, alt);
    hashCode = MurmurHash.update(hashCode, context.hashCode);
    hashCode = MurmurHash.update(hashCode, semanticContext.hashCode);
    hashCode = MurmurHash.update(hashCode, hasPassedThroughNonGreedyDecision ? 1 : 0);
    hashCode = MurmurHash.update(hashCode, lexerActionExecutor.hashCode);
    hashCode = MurmurHash.finish(hashCode, 6);
    return hashCode;
  }

  bool operator==(AtnConfig other) {
    if (other is! LexerAtnConfig) return false;
    LexerAtnConfig lexerOther = other;
    if (hasPassedThroughNonGreedyDecision
        != lexerOther.hasPassedThroughNonGreedyDecision) {
      return false;
    }
    if (lexerActionExecutor != lexerOther.lexerActionExecutor) {
      return false;
    }
    return super == other;
  }
}
