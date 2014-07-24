part of antlr4dart;

class LexerInterpreter extends Lexer {
  final String grammarFileName;
  final Atn atn;

  final List<String> tokenNames;
  final List<String> ruleNames;
  final List<String> modeNames;

  final List<Dfa> decisionToDfa;
  final sharedContextCache = new PredictionContextCache();

  LexerInterpreter(this.grammarFileName,
                   this.tokenNames,
                   this.ruleNames,
                   this.modeNames,
                   Atn atn,
                   StringSource input) : super(input),
    decisionToDfa = new List<Dfa>(atn.numberOfDecisions),
    this.atn = atn {
    if (atn.grammarType != AtnType.LEXER) {
      throw new ArgumentError("The ATN must be a lexer ATN.");
    }
    for (int i = 0; i < decisionToDfa.length; i++) {
      decisionToDfa[i] = new Dfa(atn.getDecisionState(i), i);
    }
    interpreter = new LexerAtnSimulator(
        atn, decisionToDfa, sharedContextCache, this);
  }
}

/// A parser simulator that mimics what ANTLR's generated parser code does.
/// A [ParserAtnSimulator] is used to make predictions via
/// [Parser.adaptivePredict] but this class moves a pointer through the ATN to
/// simulate parsing. [ParserAtnSimulator] just makes us efficient rather than
/// having to backtrack, for example.
///
/// This properly creates parse trees even for left recursive rules.
///
/// We rely on the left recursive rule invocation and special predicate
/// transitions to make left recursive rules work.
///
class ParserInterpreter extends Parser {
  final String grammarFileName;
  final Atn atn;
  final BitSet pushRecursionContextStates;

  final List<Dfa> decisionToDfa;
  final sharedContextCache = new PredictionContextCache();

  final List<String> tokenNames;
  final List<String> ruleNames;

  final parentContextStack = new List<Pair<ParserRuleContext, int>>();

  ParserInterpreter(this.grammarFileName,
                    this.tokenNames,
                    this.ruleNames,
                    Atn atn,
                    TokenSource input)
      : decisionToDfa = new List<Dfa>(atn.numberOfDecisions),
        pushRecursionContextStates = new BitSet(),
        this.atn = atn,
        super(input) {
    for (int i = 0; i < decisionToDfa.length; i++) {
      decisionToDfa[i] = new Dfa(atn.getDecisionState(i), i);
    }
    // identify the ATN states where pushNewRecursionContext must be called
    for (AtnState state in atn.states) {
      if (state is! StarLoopEntryState) continue;
      if ((state as StarLoopEntryState).precedenceRuleDecision) {
        pushRecursionContextStates.set(state.stateNumber, true);
      }
    }
    // get atn simulator that knows how to do predictions
    interpreter = new ParserAtnSimulator(
        this, atn, decisionToDfa, sharedContextCache);
  }

  /// Begin parsing at [startRuleIndex].
  ParserRuleContext parse(int startRuleIndex) {
    RuleStartState startRuleStartState = atn.ruleToStartState[startRuleIndex];
    var rootContext = new InterpreterRuleContext(
        null, AtnState.INVALID_STATE_NUMBER, startRuleIndex);
    if (startRuleStartState.isPrecedenceRule) {
      enterRecursionRule(rootContext,
          startRuleStartState.stateNumber, startRuleIndex, 0);
    } else {
      enterRule(rootContext, startRuleStartState.stateNumber, startRuleIndex);
    }
    while (true) {
      AtnState p = _getAtnState();
      switch (p.stateType) {
      case AtnState.RULE_STOP :
        // pop; return from rule
        if (context.isEmpty) {
          if (startRuleStartState.isPrecedenceRule) {
            ParserRuleContext result = context;
            var parentContext = parentContextStack.removeLast();
            unrollRecursionContexts(parentContext.a);
            return result;
          } else {
            exitRule();
            return rootContext;
          }
        }
        _visitRuleStopState(p);
        break;
      default :
        _visitState(p);
        break;
      }
    }
  }

  void enterRecursionRule(ParserRuleContext localctx,
                          int state,
                          int ruleIndex,
                          int precedence) {
    parentContextStack.add(
        new Pair<ParserRuleContext, int>(context, localctx.invokingState));
    super.enterRecursionRule(localctx, state, ruleIndex, precedence);
  }

  AtnState _getAtnState() => atn.states[state];

  void _visitState(AtnState antState) {
    int edge;
    if (antState.numberOfTransitions > 1) {
      edge = interpreter.adaptivePredict(_input,
          (antState as DecisionState).decision, context);
    } else {
      edge = 1;
    }
    var transition = antState.getTransition(edge - 1);
    switch (transition.serializationType) {
    case Transition.EPSILON:
      if (pushRecursionContextStates.get(antState.stateNumber)
          && (transition.target is! LoopEndState)) {
        var ctx = new InterpreterRuleContext(parentContextStack.last.a,
            parentContextStack.last.b, context.ruleIndex);
        pushNewRecursionContext(ctx,
            atn.ruleToStartState[antState.ruleIndex].stateNumber,
                context.ruleIndex);
      }
      break;
    case Transition.ATOM:
      match(transition.especialLabel);
      break;
    case Transition.RANGE:
    case Transition.SET:
    case Transition.NOT_SET:
      if (!transition.matches(
          _input.lookAhead(1), Token.MIN_USER_TOKEN_TYPE, 65535)) {
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
      var ctx = new InterpreterRuleContext(
          context, antState.stateNumber, ruleIndex);
      if (ruleStartState.isPrecedenceRule) {
        enterRecursionRule(ctx, ruleStartState.stateNumber,
            ruleIndex, transition.precedence);
      } else {
        enterRule(ctx, transition.target.stateNumber, ruleIndex);
      }
      break;
    case Transition.PREDICATE:
      PredicateTransition predicateTransition = transition;
      if (!semanticPredicate(context, predicateTransition.ruleIndex,
          predicateTransition.predIndex)) {
        throw new FailedPredicateException(this);
      }
      break;
    case Transition.ACTION:
      ActionTransition actionTransition = transition;
      action(context, actionTransition.ruleIndex, actionTransition.actionIndex);
      break;
    case Transition.PRECEDENCE:
      if (!precedencePredicate(context, transition.precedence)) {
        throw new FailedPredicateException(this,
            "precpred(context, ${transition.precedence})");
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
      var parentContext = parentContextStack.removeLast();
      unrollRecursionContexts(parentContext.a);
      state = parentContext.b;
    } else {
      exitRule();
    }
    RuleTransition ruleTransition = atn.states[state].getTransition(0);
    state = ruleTransition.followState.stateNumber;
  }
}
