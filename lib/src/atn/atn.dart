part of antlr4dart;

class Atn {
  static const int INVALID_ALT_NUMBER = 0;

  final List<AtnState> states = new List<AtnState>();

  /// Each subrule/rule is a decision point and we must track them so we
  /// can go back later and build DFA predictors for them.  This includes
  /// all the rules, subrules, optional blocks, ()+, ()* etc...
  final List<DecisionState> decisionToState = new List<DecisionState>();

  /// Maps from rule index to starting state number.
  List<RuleStartState> ruleToStartState;

  /// Maps from rule index to stop state number.
  List<RuleStopState> ruleToStopState;

  final modeNameToStartState = new LinkedHashMap<String, TokensStartState>();

  /// The type of the ATN.
  final AtnType grammarType;

  /// The maximum value for any symbol recognized by a transition in the ATN.
  final int maxTokenType;

  /// For lexer ATNs, this maps the rule index to the resulting token type.
  ///
  /// This is `null` for parser ATNs.
  List<int> ruleToTokenType;

  /// For lexer ATNs, this is an array of [LexerAction] objects which may
  /// be referenced by action transitions in the ATN.
  List<LexerAction> lexerActions;

  final List<TokensStartState> modeToStartState = new List<TokensStartState>();

  /// Used for runtime deserialization of ATNs from strings
  Atn(this.grammarType, this.maxTokenType);

  int get numberOfDecisions => decisionToState.length;

  /// Compute the set of valid tokens that can occur starting in [state].
  /// If [context] is `null`, the set of tokens will not include what can
  /// follow the rule surrounding [state]. In other words, the set will be
  /// restricted to tokens reachable staying within [state]'s rule.
  IntervalSet nextTokens(AtnState state, RuleContext context) {
    return new Ll1Analyzer(this).look(state, context);
  }

  /// Compute the set of valid tokens that can occur starting in [state] and
  /// staying in same rule. [Token.EPSILON] is in set if we reach end of
  /// rule.
  IntervalSet nextTokensInSameRule(AtnState state) {
    if (state.nextTokenWithinRule != null) return state.nextTokenWithinRule;
    return (state
        ..nextTokenWithinRule = nextTokens(state, null)
        ..nextTokenWithinRule.isReadonly = true).nextTokenWithinRule;
  }

  void addState(AtnState state) {
    if (state != null) {
      state
          ..atn = this
          ..stateNumber = states.length;
    }
    states.add(state);
  }

  void removeState(AtnState state) {
    states[state.stateNumber] = null;
  }

  int defineDecisionState(DecisionState state) {
    decisionToState.add(state);
    state.decision = decisionToState.length - 1;
    return state.decision;
  }

  DecisionState getDecisionState(int decision) {
    return decisionToState.isNotEmpty ? decisionToState[decision] : null;
  }

  /// Computes the set of input symbols which could follow ATN state number
  /// [stateNumber] in the specified full [context].
  ///
  /// This method considers the complete parser context, but does not evaluate
  /// semantic predicates (i.e. all predicates encountered during the
  /// calculation are assumed true).
  ///
  /// If a path in the ATN exists from the starting state to the [RuleStopState]
  /// of the outermost context without matching any symbols, [Token.EOF] is
  /// added to the returned set.
  ///
  /// If [context] is `null`, it is treated as [ParserRuleContext.EMPTY].
  ///
  /// [stateNumber] is the ATN state number.
  /// [context] is the full parse context.
  ///
  /// Return is the set of potentially valid input symbols which could follow
  /// the specified state in the specified context.
  /// An [ArgumentError] occurs when the ATN does not contain a state with
  /// number [stateNumber].
  IntervalSet getExpectedTokens(int stateNumber, RuleContext context) {
    if (stateNumber < 0 || stateNumber >= states.length) {
      throw new ArgumentError("Invalid state number.");
    }
    AtnState s = states[stateNumber];
    IntervalSet following = nextTokensInSameRule(s);
    if (!following.contains(Token.EPSILON)) return following;
    IntervalSet expected = new IntervalSet()
        ..addAll(following)
        ..remove(Token.EPSILON);
    while (context != null && context.invokingState >= 0
        && following.contains(Token.EPSILON)) {
      AtnState invokingState = states[context.invokingState];
      RuleTransition rt = invokingState.getTransition(0);
      following = nextTokensInSameRule(rt.followState);
      expected
          ..addAll(following)
          ..remove(Token.EPSILON);
      context = context.parent;
    }
    if (following.contains(Token.EPSILON))  expected.addSingle(Token.EOF);
    return expected;
  }
}
