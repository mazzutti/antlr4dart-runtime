part of antlr4dart;

class Atn {
  static const int INVALID_ALT_NUMBER = 0;

  final List<AtnState> states = new List<AtnState>();

  /**
   * Each subrule/rule is a decision point and we must track them so we
   * can go back later and build DFA predictors for them.  This includes
   * all the rules, subrules, optional blocks, ()+, ()* etc...
   */
  final List<DecisionState> decisionToState = new List<DecisionState>();

  /**
   * Maps from rule index to starting state number.
   */
  List<RuleStartState> ruleToStartState;

  /**
   * Maps from rule index to stop state number.
   */
  List<RuleStopState> ruleToStopState;

  final Map<String, TokensStartState> modeNameToStartState = new LinkedHashMap<String, TokensStartState>();

  /**
   * The type of the ATN.
   */
  final AtnType grammarType;

  /**
   * The maximum value for any symbol recognized by a transition in the ATN.
   */
  final int maxTokenType;

  /**
   * For lexer ATNs, this maps the rule index to the resulting token type.
   *
   * This is `null` for parser ATNs.
   */
  List<int> ruleToTokenType;

  /**
   * For lexer ATNs, this maps the rule index to the action which should be
   * executed following a match.
   *
   * This is `null` for parser ATNs.
   */
  List<int> ruleToActionIndex;

  final List<TokensStartState> modeToStartState = new List<TokensStartState>();

  /**
   * Used for runtime deserialization of ATNs from strings
   */
  Atn(this.grammarType, this.maxTokenType);

  /**
   * Compute the set of valid tokens that can occur starting in state `s`.
   * If `ctx` is null, the set of tokens will not include what can follow
   * the rule surrounding `s`. In other words, the set will be
   * restricted to tokens reachable staying within `s`'s rule.
   */
  IntervalSet nextTokens(AtnState s, RuleContext ctx) {
    Ll1Analyzer analizer = new Ll1Analyzer(this);
    IntervalSet next = analizer.look(s, ctx);
    return next;
  }

 /**
   * Compute the set of valid tokens that can occur starting in `s` and
   * staying in same rule. [Token.EPSILON] is in set if we reach end of
   * rule.
   */
  IntervalSet nextTokensInSameRule(AtnState s) {
    if (s.nextTokenWithinRule != null ) return s.nextTokenWithinRule;
    s.nextTokenWithinRule = nextTokens(s, null);
    s.nextTokenWithinRule.isReadonly = true;
    return s.nextTokenWithinRule;
  }

  void addState(AtnState state) {
    if (state != null) {
      state.atn = this;
      state.stateNumber = states.length;
    }
    states.add(state);
  }

  void removeState(AtnState state) {
    // just free mem, don't shift states in list
    states[state.stateNumber] = null;
  }

  int defineDecisionState(DecisionState s) {
    decisionToState.add(s);
    s.decision = decisionToState.length - 1;
    return s.decision;
  }

  DecisionState getDecisionState(int decision) {
    if (decisionToState.isNotEmpty) {
      return decisionToState[decision];
    }
    return null;
  }

  int get numberOfDecisions => decisionToState.length;

  /**
   * Computes the set of input symbols which could follow ATN state number
   * `stateNumber` in the specified full `context`. This method considers the
   * complete parser context, but does not evaluate semantic predicates (i.e.
   * all predicates encountered during the calculation are assumed true).
   * If a path in the ATN exists from the starting state to the [RuleStopState]
   * of the outermost context without matching any symbols, [Token.EOF] is
   * added to the returned set.
   *
   * If `context` is `null`, it is treated as [ParserRuleContext.EMPTY].
   *
   * [stateNumber] is the ATN state number.
   * [context] is the full parse context.
   * Return is the set of potentially valid input symbols which could follow the
   * specified state in the specified context.
   * Throws [ArgumentError] if the ATN does not contain a state with
   * number `stateNumber`.
   */
  IntervalSet getExpectedTokens(int stateNumber, RuleContext context) {
    if (stateNumber < 0 || stateNumber >= states.length) {
      throw new ArgumentError("Invalid state number.");
    }
    RuleContext ctx = context;
    AtnState s = states[stateNumber];
    IntervalSet following = nextTokensInSameRule(s);
    if (!following.contains(Token.EPSILON)) {
      return following;
    }
    IntervalSet expected = new IntervalSet();
    expected.addAll(following);
    expected.remove(Token.EPSILON);
    while (ctx != null && ctx.invokingState >= 0 && following.contains(Token.EPSILON)) {
      AtnState invokingState = states[ctx.invokingState];
      RuleTransition rt = invokingState.transition(0);
      following = nextTokensInSameRule(rt.followState);
      expected.addAll(following);
      expected.remove(Token.EPSILON);
      ctx = ctx.parent;
    }
    if (following.contains(Token.EPSILON)) {
      expected.addSingle(Token.EOF);
    }
    return expected;
  }
}
