part of antlr4dart;

abstract class AtnSimulator {

  static const int SERIALIZED_VERSION = 3;

  static const String SERIALIZED_UUID = "33761B2D-78BB-4A43-8B0B-4F5BEE8AACF3";

  /**
   * Must distinguish between missing edge and edge we know leads nowhere
   */
  static final DfaState ERROR = () {
    var dfa = new DfaState.config(new AtnConfigSet());
    dfa.stateNumber = pow(2, 53) - 1;
    return dfa;
  }();

  final Atn atn;

  /**
   * The context cache maps all [PredictionContext] objects that are `==`
   * to a single cached copy. This cache is shared across all contexts
   * in all [AtnConfig]s in all DFA states.  We rebuild each [AtnConfigSet]
   * to use only cached nodes/graphs in `addDfaState()`. We don't want to
   * fill this during `closure()` since there are lots of contexts that
   * pop up but are not used ever again. It also greatly slows down `closure()`.
   */
  final PredictionContextCache _sharedContextCache;

  AtnSimulator(this.atn, this._sharedContextCache);

  void reset();

  PredictionContextCache get sharedContextCache {
    return _sharedContextCache;
  }

  PredictionContext getCachedContext(PredictionContext context) {
    if (_sharedContextCache == null) return context;
    var visited = new HashMap<PredictionContext, PredictionContext>();
    return PredictionContext.getCachedContext(context, sharedContextCache, visited);
  }

  static Atn deserialize(String data) {
    RuneIterator iterator = data.runes.iterator;
    List<int> codes = new List<int>();
    while (iterator.moveNext()) codes.add(iterator.current - 2);
    int p = 0;
    int version = codes[p++] + 2;
    if (version != SERIALIZED_VERSION) {
      throw new UnsupportedError(
          "Could not deserialize ATN with version $version (expected $SERIALIZED_VERSION).");
    }
    String uuid = toUuid(codes.getRange(p, p += 8).toList());
    if (uuid != SERIALIZED_UUID) {
      throw new UnsupportedError(
          "Could not deserialize ATN with UUID $uuid (expected $SERIALIZED_UUID).");
    }
    AtnType grammarType = AtnType.values[codes[p++]];
    int maxTokenType = codes[p++];
    Atn atn = new Atn(grammarType, maxTokenType);
    // STATES
    var loopBackStateNumbers = new List<Pair<LoopEndState, int>>();
    var endStateNumbers = new List<Pair<BlockStartState, int>>();
    int nstates = codes[p++];
    for (int i = 0; i < nstates; i++) {
      int stype = codes[p++];
      // ignore bad type of states
      if (stype == AtnState.INVALID_TYPE) {
        atn.addState(null);
        continue;
      }
      var code = codes[p++];
      int ruleIndex = (code == -1) ? 65535: code;
      AtnState s = stateFactory(stype, ruleIndex);
      if (stype == AtnState.LOOP_END) { // special case
        int loopBackStateNumber = codes[p++];
        loopBackStateNumbers.add(new Pair<LoopEndState, int>(s, loopBackStateNumber));
      } else if (s is BlockStartState) {
        int endStateNumber = codes[p++];
        endStateNumbers.add(new Pair<BlockStartState, int>(s, endStateNumber));
      }
      atn.addState(s);
    }
    // delay the assignment of loop back and end states until we
    // know all the state instances have been initialized
    for (Pair<LoopEndState, int> pair in loopBackStateNumbers) {
      pair.a.loopBackState = atn.states[pair.b];
    }
    for (Pair<BlockStartState, int> pair in endStateNumbers) {
      pair.a.endState = atn.states[pair.b];
    }
    int numNonGreedyStates = codes[p++];
    for (int i = 0; i < numNonGreedyStates; i++) {
      int stateNumber = codes[p++] ;
      (atn.states[stateNumber] as DecisionState).nonGreedy = true;
    }
    // RULES
    int nrules = codes[p++];
    if (atn.grammarType == AtnType.LEXER) {
      atn.ruleToTokenType = new List<int>(nrules);
      atn.ruleToActionIndex = new List<int>(nrules);
    }
    atn.ruleToStartState = new List<RuleStartState>(nrules);
    for (int i = 0; i < nrules; i++) {
      int s = codes[p++];
      RuleStartState startState = atn.states[s];
      atn.ruleToStartState[i] = startState;
      if (atn.grammarType == AtnType.LEXER) {
        int tokenType = codes[p++];
        if (tokenType == 0xFFFF) tokenType = Token.EOF;
        atn.ruleToTokenType[i] = tokenType;
        int actionIndex = codes[p++];
        if (actionIndex == -1) actionIndex = 65535;
        atn.ruleToActionIndex[i] = actionIndex;
      }
    }
    atn.ruleToStopState = new List<RuleStopState>(nrules);
    for (AtnState state in atn.states) {
      if (state is! RuleStopState) continue;
      atn.ruleToStopState[state.ruleIndex] = state;
      atn.ruleToStartState[state.ruleIndex].stopState = state;
    }
    // MODES
    int nmodes = codes[p++];
    for (int i = 0; i < nmodes; i++) {
      var t = atn.states[codes[p++]];
      atn.modeToStartState.add(t);
    }
    // SETS
    List<IntervalSet> sets = new List<IntervalSet>();
    int nsets = codes[p++];
    for (int i = 0; i < nsets; i++) {
      int nintervals = codes[p++];
      IntervalSet set = new IntervalSet();
      sets.add(set);
      bool containsEof = codes[p++] != 0;
      if (containsEof) set.addSingle(-1);
      for (int j = 0; j < nintervals; j++) {
        set.add(codes[p++], codes[p++]);
      }
    }
    // EDGES
    int nedges = codes[p++];
    for (int i = 0; i < nedges; i++) {
      int src = codes[p++];
      int trg = codes[p++];
      int ttype = codes[p++];
      int arg1 = codes[p++];
      int arg2 = codes[p++];
      arg2 = (arg2 == -1) ? 65535: arg2;
      int arg3 = codes[p++];
      Transition trans = edgeFactory(atn, ttype, src, trg, arg1, arg2, arg3, sets);
      AtnState srcState = atn.states[src];
      srcState.addTransition(trans);
    }
    // edges for rule stop states can be derived, so they aren't serialized
    for (AtnState state in atn.states) {
      for (int i = 0; i < state.numberOfTransitions; i++) {
        Transition t = state.transition(i);
        if (t is! RuleTransition) continue;
        atn.ruleToStopState[t.target.ruleIndex].addTransition(
            new EpsilonTransition((t as RuleTransition).followState));
      }
    }
    for (AtnState state in atn.states) {
      if (state is BlockStartState) {
        // we need to know the end state to set its start state
        if (state.endState == null)
          throw new StateError('we need to know the end state to set its start state');
        // block end states can only be associated to a single block start state
        if (state.endState.startState != null)
          throw new StateError('block end states can only be associated to a single block start state');
        state.endState.startState = state;
      }
      if (state is PlusLoopbackState) {
        for (int i = 0; i < state.numberOfTransitions; i++) {
          AtnState target = state.transition(i).target;
          if (target is PlusBlockStartState) {
            target.loopBackState = state;
          }
        }
      } else if (state is StarLoopbackState) {
        for (int i = 0; i < state.numberOfTransitions; i++) {
          AtnState target = state.transition(i).target;
          if (target is StarLoopEntryState) {
            target.loopBackState = state;
          }
        }
      }
    }
    // DECISIONS
    int ndecisions = codes[p++];
    for (int i = 1; i <= ndecisions; i++) {
      DecisionState decState = atn.states[codes[p++]];
      atn.decisionToState.add(decState);
      decState.decision = i-1;
    }
    _verifyAtn(atn);
    return atn;
  }

  static void _verifyAtn(Atn atn) {
    // verify assumptions
    for (AtnState state in atn.states) {
      if (state == null) continue;
      checkCondition(state.onlyHasEpsilonTransitions || (state.numberOfTransitions <= 1));
      if (state is PlusBlockStartState) checkCondition(state.loopBackState != null);
      if (state is StarLoopEntryState) {
        checkCondition(state.loopBackState != null);
        checkCondition(state.numberOfTransitions == 2);
        if (state.transition(0).target is StarBlockStartState) {
          checkCondition(state.transition(1).target is LoopEndState);
          checkCondition(!state.nonGreedy);
        } else if (state.transition(0).target is LoopEndState) {
          checkCondition(state.transition(1).target is StarBlockStartState);
          checkCondition(state.nonGreedy);
        } else {
          throw new StateError('');
        }
      }
      if (state is StarLoopbackState) {
        checkCondition(state.numberOfTransitions == 1);
        checkCondition(state.transition(0).target is StarLoopEntryState);
      }
      if (state is LoopEndState) checkCondition(state.loopBackState != null);
      if (state is RuleStartState) checkCondition(state.stopState != null);
      if (state is BlockStartState) checkCondition(state.endState != null);
      if (state is BlockEndState) checkCondition(state.startState != null);
      if (state is DecisionState) {
        checkCondition(state.numberOfTransitions <= 1 || state.decision >= 0);
      } else {
        checkCondition(state.numberOfTransitions <= 1 || state is RuleStopState);
      }
    }
  }


  static void checkCondition(bool condition, [String message]) {
    if (!condition) {
      throw new StateError(message);
    }
  }

  static String toUuid(List<int> data) {
    int leastSigBits = _toInt(data);
    int mostSigBits = _toInt(data, 4);
    String uuid = "${_digits(mostSigBits >> 32, 8)}-"
                  "${_digits(mostSigBits >> 16, 4)}-"
                  "${_digits(mostSigBits, 4)}-"
                  "${_digits(leastSigBits >> 48, 4)}-"
                  "${_digits(leastSigBits, 12)}";
    return uuid.toUpperCase();
  }

  static int _toInt(List<int> data, [int offset = 0]) {
    int lowOrder = (data[offset] | (data[offset + 1] << 16)) & 0x00000000FFFFFFFF;
    return lowOrder | ((data[offset + 2] | (data[offset + 3] << 16)) << 32);
  }


  static String _digits(int paramLong, int paramInt) {
    int l = 1 << paramInt * 4;
    return (l | paramLong & l - 1).toRadixString(16).substring(1);
  }

  static Transition edgeFactory(Atn atn,
                                int type,
                                int src,
                                int trg,
                                int arg1,
                                int arg2,
                                int arg3,
                                List<IntervalSet> sets) {
    AtnState target = atn.states[trg];
    switch (type) {
      case Transition.EPSILON : return new EpsilonTransition(target);
      case Transition.RANGE :
        if (arg3 != 0) return new RangeTransition(target, Token.EOF, arg2);
        return new RangeTransition(target, arg1, arg2);
      case Transition.RULE :
        return new RuleTransition(atn.states[arg1], arg2, target);
      case Transition.PREDICATE :
        return new PredicateTransition(target, arg1, arg2, arg3 != 0);
      case Transition.ATOM :
        if (arg3 != 0) return new AtomTransition(target, Token.EOF);
        return new AtomTransition(target, arg1);
      case Transition.ACTION :
        return new ActionTransition(target, arg1, arg2, arg3 != 0);
      case Transition.SET : return new SetTransition(target, sets[arg1]);
      case Transition.NOT_SET : return new NotSetTransition(target, sets[arg1]);
      case Transition.WILDCARD : return new WildcardTransition(target);
    }
    throw new ArgumentError("The specified transition type is not valid.");
  }

  static AtnState stateFactory(int type, int ruleIndex) {
    AtnState s;
    switch (type) {
      case AtnState.INVALID_TYPE: return null;
      case AtnState.BASIC : s = new BasicState(); break;
      case AtnState.RULE_START : s = new RuleStartState(); break;
      case AtnState.BLOCK_START : s = new BasicBlockStartState(); break;
      case AtnState.PLUS_BLOCK_START : s = new PlusBlockStartState(); break;
      case AtnState.STAR_BLOCK_START : s = new StarBlockStartState(); break;
      case AtnState.TOKEN_START : s = new TokensStartState(); break;
      case AtnState.RULE_STOP : s = new RuleStopState(); break;
      case AtnState.BLOCK_END : s = new BlockEndState(); break;
      case AtnState.STAR_LOOP_BACK : s = new StarLoopbackState(); break;
      case AtnState.STAR_LOOP_ENTRY : s = new StarLoopEntryState(); break;
      case AtnState.PLUS_LOOP_BACK : s = new PlusLoopbackState(); break;
      case AtnState.LOOP_END : s = new LoopEndState(); break;
      default :
        throw new ArgumentError("The specified state type $type is not valid.");
    }
    s.ruleIndex = ruleIndex;
    return s;
  }
}
