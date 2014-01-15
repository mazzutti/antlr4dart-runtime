part of antlr4dart;

/**
 * A parser simulator that mimics what ANTLR's generated
 * parser code does. A [ParserAtnSimulator] is used to make
 * predictions via adaptivePredict but this class moves a pointer
 * through the ATN to simulate parsing. ParserAtnSimulator just
 * makes us efficient rather than having to backtrack, for example.
 *
 * This properly creates parse trees even for left recursive rules.
 *
 * We rely on the left recursive rule invocation and special predicate
 * transitions to make left recursive rules work.
 *
 */
class ParserInterpreter extends Parser {
  final String grammarFileName;
  final Atn atn;
  final BitSet pushRecursionContextStates;

  final List<Dfa> decisionToDFA;
  final PredictionContextCache sharedContextCache = new PredictionContextCache();

  final List<String> tokenNames;
  final List<String> ruleNames;

  final List<Pair<ParserRuleContext, int>> parentContextStack = new List<Pair<ParserRuleContext, int>>();

  ParserInterpreter(this.grammarFileName,
                    this.tokenNames,
                    this.ruleNames,
                    Atn atn,
                    TokenSource input)
    :super(input),
    decisionToDFA = new List<Dfa>(atn.numberOfDecisions),
    pushRecursionContextStates = new BitSet(atn.states.length),
    this.atn = atn {
    for (int i = 0; i < decisionToDFA.length; i++) {
      decisionToDFA[i] = new Dfa(atn.getDecisionState(i), i);
    }
    // identify the ATN states where pushNewRecursionContext must be called
    for (AtnState state in atn.states) {
      if (state is! StarLoopEntryState) {
        continue;
      }
      if ((state as StarLoopEntryState).precedenceRuleDecision) {
        this.pushRecursionContextStates.set(state.stateNumber, true);
      }
    }
    // get atn simulator that knows how to do predictions
    interpreter = new ParserAtnSimulator(this, atn, decisionToDFA, sharedContextCache);
  }

  /**
   * Begin parsing at `startRuleIndex`.
   */
  ParserRuleContext parse(int startRuleIndex) {
    RuleStartState startRuleStartState = atn.ruleToStartState[startRuleIndex];
    InterpreterRuleContext rootContext = new InterpreterRuleContext(null, AtnState.INVALID_STATE_NUMBER, startRuleIndex);
    if (startRuleStartState.isPrecedenceRule) {
      enterRecursionRule(rootContext, startRuleStartState.stateNumber, startRuleIndex, 0);
    } else {
      enterRule(rootContext, startRuleStartState.stateNumber, startRuleIndex);
    }
    while (true) {
      AtnState p = _getAtnState();
      switch (p.stateType) {
      case AtnState.RULE_STOP :
        // pop; return from rule
        if (context.isEmpty) {
          exitRule();
          return rootContext;
        }
        _visitRuleStopState(p);
        break;
      default :
        _visitState(p);
        break;
      }
    }
  }

  void enterRecursionRule(ParserRuleContext localctx, int state, int ruleIndex, int precedence) {
    parentContextStack.add(new Pair<ParserRuleContext, int>(context, localctx.invokingState));
    super.enterRecursionRule(localctx, state, ruleIndex, precedence);
  }

  AtnState _getAtnState() {
    return atn.states[state];
  }

  void _visitState(AtnState p) {
    int edge;
    if (p.numberOfTransitions > 1) {
      edge = interpreter.adaptivePredict(_input, (p as DecisionState).decision, context);
    } else {
      edge = 1;
    }
    Transition transition = p.transition(edge - 1);
    switch (transition.serializationType) {
    case Transition.EPSILON:
      if (pushRecursionContextStates.get(p.stateNumber) && (transition.target is! LoopEndState)) {
        InterpreterRuleContext ctx = new InterpreterRuleContext(
            parentContextStack.last.a, parentContextStack.last.b, context.ruleIndex);
        pushNewRecursionContext(ctx, atn.ruleToStartState[p.ruleIndex].stateNumber, context.ruleIndex);
      }
      break;
    case Transition.ATOM:
      match((transition as AtomTransition).especialLabel);
      break;
    case Transition.RANGE:
    case Transition.SET:
    case Transition.NOT_SET:
      if (!transition.matches(_input.lookAhead(1), Token.MIN_USER_TOKEN_TYPE, 65535)) {
        errorHandler.recoverInline(this);
      }
      matchWildcard();
      break;
    case Transition.WILDCARD:
      matchWildcard();
      break;
    case Transition.RULE:
      RuleStartState ruleStartState = transition.target;
      int ruleIndex = ruleStartState.ruleIndex;
      InterpreterRuleContext ctx = new InterpreterRuleContext(context, p.stateNumber, ruleIndex);
      if (ruleStartState.isPrecedenceRule) {
        enterRecursionRule(ctx, ruleStartState.stateNumber, ruleIndex, (transition as RuleTransition).precedence);
      } else {
        enterRule(ctx, transition.target.stateNumber, ruleIndex);
      }
      break;
    case Transition.PREDICATE:
      PredicateTransition predicateTransition = transition;
      if (!sempred(context, predicateTransition.ruleIndex, predicateTransition.predIndex)) {
        throw new FailedPredicateException(this);
      }
      break;
    case Transition.ACTION:
      ActionTransition actionTransition = transition;
      action(context, actionTransition.ruleIndex, actionTransition.actionIndex);
      break;
    case Transition.PRECEDENCE:
      if (!precpred(context, (transition as PrecedencePredicateTransition).precedence)) {
        throw new FailedPredicateException(this,
            "precpred(context, ${(transition as PrecedencePredicateTransition).precedence})");
      }
      break;
    default:
      throw new UnsupportedError("Unrecognized ATN transition type.");
    }
    state = transition.target.stateNumber;
  }

  void _visitRuleStopState(AtnState p) {
    RuleStartState ruleStartState = atn.ruleToStartState[p.ruleIndex];
    if (ruleStartState.isPrecedenceRule) {
      Pair<ParserRuleContext, int> parentContext = parentContextStack.removeLast();
      unrollRecursionContexts(parentContext.a);
      state = parentContext.b;
    } else {
      exitRule();
    }
    RuleTransition ruleTransition = atn.states[state].transition(0);
    state = ruleTransition.followState.stateNumber;
  }
}