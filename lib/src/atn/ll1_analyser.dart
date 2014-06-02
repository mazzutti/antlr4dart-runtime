part of antlr4dart;

class Ll1Analyzer {

  /// Special value added to the lookahead sets to indicate that we hit
  /// a predicate during analysis if `seeThruPreds == false`.
  static const int HIT_PRED = Token.INVALID_TYPE;

  final Atn atn;

  Ll1Analyzer(this.atn);

  /// Calculates the SLL(1) expected lookahead set for each outgoing transition
  /// of an [AtnState].
  ///
  /// The returned array has one element for each outgoing transition in `s`.
  /// If the closure from transition **i** leads to a semantic predicate before
  /// matching a symbol, the element at index **i** of the result will be `null`.
  ///
  /// [state] is the ATN state.
  ///
  /// Return the expected symbols for each outgoing transition of `s`.
  List<IntervalSet> getDecisionLookahead(AtnState state) {
    if (state == null) return null;
    List<IntervalSet> look = new List<IntervalSet>(state.numberOfTransitions);
    for (int alt = 0; alt < state.numberOfTransitions; alt++) {
      look[alt] = new IntervalSet();
      Set<AtnConfig> lookBusy = new HashSet<AtnConfig>();
      bool seeThruPreds = false; // fail to get lookahead upon pred
      _look(state.getTransition(alt).target, null, PredictionContext.EMPTY,
          look[alt], lookBusy, new BitSet(), seeThruPreds, false);
      // Wipe out lookahead for this alternative if we found nothing
      // or we had a predicate when we !seeThruPreds
      if (look[alt].length == 0 || look[alt].contains(HIT_PRED)) {
        look[alt] = null;
      }
    }
    return look;
  }

  /// Compute set of tokens that can follow [state] in the ATN in the specified
  /// [context].
  ///
  /// If [context] is `null` and the end of the rule containing [state] is
  /// reached, [Token.EPSILON] is added to the result set. If [context] is not
  /// `null` and the end of the outermost rule is reached, [Token.EOF] is added
  /// to the result set.
  ///
  /// [state] is the ATN state
  /// [stopState] is the ATN state to stop at. This can be a [BlockEndState] to
  /// detect epsilon paths through a closure.
  /// [context] is the complete parser context, or `null` if the context
  /// should be ignored
  ///
  /// Return the set of tokens that can follow [state] in the ATN in the
  /// specified [context].
  IntervalSet look(AtnState state, RuleContext context, [AtnState stopState]) {
    IntervalSet r = new IntervalSet();
    bool seeThruPreds = true; // ignore preds; get all lookahead
    var lookContext = context != null
        ? new PredictionContext.fromRuleContext(state.atn, context) : null;
    _look(state, stopState, lookContext, r,
        new HashSet<AtnConfig>(), new BitSet(), seeThruPreds, true);
    return r;
  }

  /// Compute set of tokens that can follow [state] in the ATN in the
  /// specified [context].
  ///
  /// If [context] is `null` and [stopState] or the end of the rule containing
  /// [state] is reached, [Token.EPSILON] is added to the result set. If
  /// [context] is not `null` and [addEof] is `true` and [stopState] or the
  /// end of the outermost rule is reached, [Token.EOF] is added to the result
  /// set.
  ///
  /// [state] is the ATN state.
  /// [stopState] is the ATN state to stop at. This can be a [BlockEndState] to
  /// detect epsilon paths through a closure.
  /// [context] is the outer context, or `null` if the outer context should
  /// not be used.
  /// [look] is the result lookahead set.
  /// [lookBusy] is a set used for preventing epsilon closures in the ATN
  /// from causing a stack overflow. Outside code should pass
  /// `new HashSet<AtnConfig>()` for this argument.
  /// [calledRuleStack] is A set used for preventing left recursion in the
  /// ATN from causing a stack overflow. Outside code should pass `new BitSet()`
  /// for this argument.
  /// [seeThruPreds] is `true` to true semantic predicates as implicitly `true`
  /// and "see through them", otherwise `false` to treat semantic predicates as
  /// opaque and add [HIT_PRED] to the result if one is encountered.
  /// [addEof] tells to add [Token.EOF] to the result if the end of the
  /// outermost context is reached. This parameter has no effect if [context]
  /// is `null`.
   void _look(AtnState state,
              AtnState stopState,
              PredictionContext context,
              IntervalSet look,
              Set<AtnConfig> lookBusy,
              BitSet calledRuleStack,
              bool seeThruPreds, bool addEof) {
      AtnConfig c = new AtnConfig(state, 0, context);
      if (!lookBusy.add(c)) return;
      if (state == stopState) {
        if (context == null) {
          look.addSingle(Token.EPSILON);
          return;
        } else if (context.isEmpty && addEof) {
          look.addSingle(Token.EOF);
          return;
        }
      }
      if (state is RuleStopState) {
        if ( context==null ) {
            look.addSingle(Token.EPSILON);
            return;
        } else if (context.isEmpty && addEof) {
          look.addSingle(Token.EOF);
          return;
        }
        if (context != PredictionContext.EMPTY ) {
          // run thru all possible stack tops in ctx
          for (int i = 0; i < context.length; i++) {
            AtnState returnState = atn.states[context.getReturnState(i)];
            bool removed = calledRuleStack.get(returnState.ruleIndex);
            try {
              calledRuleStack.set(returnState.ruleIndex);
              _look(returnState, stopState, context.getParent(i),
                  look, lookBusy, calledRuleStack, seeThruPreds, addEof);
            } finally {
              if (removed) {
                calledRuleStack.set(returnState.ruleIndex, true);
              }
            }
          }
          return;
        }
      }
      int n = state.numberOfTransitions;
      for (int i = 0; i < n; i++) {
      Transition transition = state.getTransition(i);
      if (transition.runtimeType == RuleTransition) {
        if (calledRuleStack.get(transition.target.ruleIndex)) {
          continue;
        }
        PredictionContext newContext =
          new SingletonPredictionContext.empty(
              context, (transition as RuleTransition).followState.stateNumber);
        try {
          calledRuleStack.set(
              (transition as RuleTransition).target.ruleIndex, true);
          _look(transition.target, stopState, newContext,
              look, lookBusy, calledRuleStack, seeThruPreds, addEof);
        }
        finally {
          calledRuleStack.clear((transition as RuleTransition).target.ruleIndex);
        }
      } else if (transition is AbstractPredicateTransition) {
        if (seeThruPreds) {
          _look(transition.target, stopState, context,
              look, lookBusy, calledRuleStack, seeThruPreds, addEof);
        } else {
          look.addSingle(HIT_PRED);
        }
      } else if (transition.isEpsilon) {
        _look(transition.target, stopState, context, look,
            lookBusy, calledRuleStack, seeThruPreds, addEof);
      } else if (transition.runtimeType == WildcardTransition) {
        look.addAll(IntervalSet.of(Token.MIN_USER_TOKEN_TYPE, atn.maxTokenType));
      } else {
        IntervalSet set = transition.label;
        if (set != null) {
          if (transition is NotSetTransition) {
            set = set.complement(
                IntervalSet.of(Token.MIN_USER_TOKEN_TYPE, atn.maxTokenType));
          }
          look.addAll(set);
        }
      }
    }
  }
}