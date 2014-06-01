part of antlr4dart;

class AtnDeserializer {

  static const String _BASE_SERIALIZED_UUID = "33761B2D-78BB-4A43-8B0B-4F5BEE8AACF3";
  static const String _ADDED_PRECEDENCE_TRANSITIONS = "1DA0C57D-6C06-438A-9B27-10BCB3CE0F61";
  static const String _ADDED_LEXER_ACTIONS = "AADB8D7E-AEEF-4415-AD2B-8204D6CF042E";

  static const int SERIALIZED_VERSION = 3;

  static const String SERIALIZED_UUID = _ADDED_LEXER_ACTIONS;

  static const List<String> _SUPPORTED_UUIDS = const <String>[
    _BASE_SERIALIZED_UUID,
    _ADDED_PRECEDENCE_TRANSITIONS,
    _ADDED_LEXER_ACTIONS
  ];

  final AtnDeserializationOptions _deserializationOptions;

  AtnDeserializer([AtnDeserializationOptions deserializationOptions])
      : _deserializationOptions =  (deserializationOptions != null)
        ? deserializationOptions : AtnDeserializationOptions.defaultOptions;

  Atn deserialize(String data) {
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

    if (!_SUPPORTED_UUIDS.contains(uuid)) {
      String reason = "Could not deserialize ATN with UUID $uuid (expected $SERIALIZED_UUID or a legacy UUID).";
      throw new UnsupportedError(reason);
    }

    bool supportsPrecedencePredicates = _isFeatureSupported(_ADDED_PRECEDENCE_TRANSITIONS, uuid);
    bool supportsLexerActions = _isFeatureSupported(_ADDED_LEXER_ACTIONS, uuid);

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
      var ruleIndex = codes[p++];
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

    if (supportsPrecedencePredicates) {
      int numPrecedenceStates = codes[p++];
      for (int i = 0; i < numPrecedenceStates; i++) {
        int stateNumber = codes[p++];
        (atn.states[stateNumber] as RuleStartState).isPrecedenceRule = true;
      }
    }

    // RULES
    int nrules = codes[p++];
    if (atn.grammarType == AtnType.LEXER) {
      atn.ruleToTokenType = new List<int>(nrules);
    }
    atn.ruleToStartState = new List<RuleStartState>(nrules);
    for (int i = 0; i < nrules; i++) {
      int s = codes[p++];
      RuleStartState startState = atn.states[s];
      atn.ruleToStartState[i] = startState;
      if (atn.grammarType == AtnType.LEXER) {
        int tokenType = codes[p++];
        atn.ruleToTokenType[i] = tokenType;
        if (!_isFeatureSupported(_ADDED_LEXER_ACTIONS, uuid)) {
          // this piece of unused metadata was serialized prior to the
          // addition of LexerAction
          int actionIndexIgnored = codes[p++];
        }
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

    // LEXER ACTIONS
    //
    if (atn.grammarType == AtnType.LEXER) {
      if (supportsLexerActions) {
        atn.lexerActions = new List<LexerAction>(codes[p++]);
        for (int i = 0; i < atn.lexerActions.length; i++) {
            LexerActionType actionType = LexerActionType.values[codes[p++]];
            int data1 = codes[p++];
            int data2 = codes[p++];
            LexerAction lexerAction = _lexerActionFactory(actionType, data1, data2);
            atn.lexerActions[i] = lexerAction;
          }
      } else {
        // for compatibility with older serialized ATNs, convert the old
        // serialized action index for action transitions to the new
        // form, which is the index of a LexerCustomAction
        List<LexerAction> legacyLexerActions = new List<LexerAction>();
        for (AtnState state in atn.states) {
          for (int i = 0; i < state.numberOfTransitions; i++) {
            Transition transition = state.transition(i);
            if (transition is! ActionTransition) continue;
            int ruleIndex = (transition as ActionTransition).ruleIndex;
            int actionIndex = (transition as ActionTransition).actionIndex;
            LexerCustomAction lexerAction = new LexerCustomAction(ruleIndex, actionIndex);
            state.setTransition(i, new ActionTransition(transition.target, ruleIndex, legacyLexerActions.length, false));
            legacyLexerActions.add(lexerAction);
          }
        }
        atn.lexerActions = legacyLexerActions;
      }
    }

    _markPrecedenceDecisions(atn);

    if (_deserializationOptions.isVerifyAtn) {
      _verifyAtn(atn);
    }

    if (_deserializationOptions.isGenerateRuleBypassTransitions && atn.grammarType == AtnType.PARSER) {
      atn.ruleToTokenType = new List<int>(atn.ruleToStartState.length);
      for (int i = 0; i < atn.ruleToStartState.length; i++) {
        atn.ruleToTokenType[i] = atn.maxTokenType + i + 1;
      }
      for (int i = 0; i < atn.ruleToStartState.length; i++) {
        BasicBlockStartState bypassStart = new BasicBlockStartState();
        bypassStart.ruleIndex = i;
        atn.addState(bypassStart);
        BlockEndState bypassStop = new BlockEndState();
        bypassStop.ruleIndex = i;
        atn.addState(bypassStop);
        bypassStart.endState = bypassStop;
        atn.defineDecisionState(bypassStart);
        bypassStop.startState = bypassStart;
        AtnState endState;
        Transition excludeTransition = null;
        if (atn.ruleToStartState[i].isPrecedenceRule) {
          // wrap from the beginning of the rule to the StarLoopEntryState
          endState = null;
          for (AtnState state in atn.states) {
            if (state.ruleIndex != i) continue;
            if (state is! StarLoopEntryState) continue;
            AtnState maybeLoopEndState = state.transition(state.numberOfTransitions - 1).target;
            if (maybeLoopEndState is! LoopEndState) continue;
            if (maybeLoopEndState.epsilonOnlyTransitions && maybeLoopEndState.transition(0).target is RuleStopState) {
              endState = state;
              break;
            }
          }
          if (endState == null) {
            throw new UnsupportedError("Couldn't identify final state of the precedence rule prefix section.");
          }
          excludeTransition = (endState as StarLoopEntryState).loopBackState.transition(0);
        } else {
          endState = atn.ruleToStopState[i];
        }
        // all non-excluded transitions that currently target end state need to target blockEnd instead
        for (AtnState state in atn.states) {
          for (Transition transition in state.transitions) {
            if (transition == excludeTransition) continue;
            if (transition.target == endState) {
              transition.target = bypassStop;
            }
          }
        }
        // all transitions leaving the rule start state need to leave blockStart instead
        while (atn.ruleToStartState[i].numberOfTransitions > 0) {
          Transition transition = atn.ruleToStartState[i].removeTransition(atn.ruleToStartState[i].numberOfTransitions - 1);
          bypassStart.addTransition(transition);
        }
        // link the new states
        atn.ruleToStartState[i].addTransition(new EpsilonTransition(bypassStart));
        bypassStop.addTransition(new EpsilonTransition(endState));

        AtnState matchState = new BasicState();
        atn.addState(matchState);
        matchState.addTransition(new AtomTransition(bypassStop, atn.ruleToTokenType[i]));
        bypassStart.addTransition(new EpsilonTransition(matchState));
      }
      if (_deserializationOptions.isVerifyAtn) {
        // reverify after modification
        _verifyAtn(atn);
      }
    }
    return atn;
  }

  /**
   * Analyze the {@link StarLoopEntryState} states in the specified ATN to set
   * the {@link StarLoopEntryState#precedenceRuleDecision} field to the
   * correct value.
   *
   * @param atn The ATN.
   */
  void _markPrecedenceDecisions(Atn atn) {
    for (AtnState state in atn.states) {
      if (state is! StarLoopEntryState) continue;
      // We analyze the ATN to determine if this ATN decision state is the
      // decision for the closure block that determines whether a
      // precedence rule should continue or complete.
      if (atn.ruleToStartState[state.ruleIndex].isPrecedenceRule) {
        AtnState maybeLoopEndState = state.transition(state.numberOfTransitions - 1).target;
        if (maybeLoopEndState is LoopEndState) {
          if (maybeLoopEndState.epsilonOnlyTransitions && maybeLoopEndState.transition(0).target is RuleStopState) {
            (state as StarLoopEntryState).precedenceRuleDecision = true;
          }
        }
      }
    }
  }

  LexerAction _lexerActionFactory(LexerActionType type, int data1, int data2) {
    switch (type) {
      case LexerActionType.CHANNEL:
        return new LexerChannelAction(data1);
      case LexerActionType.CUSTOM:
        return new LexerCustomAction(data1, data2);
      case LexerActionType.MODE:
        return new LexerModeAction(data1);
      case LexerActionType.MORE:
        return LexerMoreAction.INSTANCE;
      case LexerActionType.POP_MODE:
        return LexerPopModeAction.INSTANCE;
      case LexerActionType.PUSH_MODE:
        return new LexerPushModeAction(data1);
      case LexerActionType.SKIP:
        return LexerSkipAction.INSTANCE;
      case LexerActionType.TYPE:
        return new LexerTypeAction(data1);
      default:
        String message = "The specified lexer action type $type is not valid.";
        throw new ArgumentError(message);
      }
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
        return new RuleTransition(atn.states[arg1], arg2, arg3, target);
      case Transition.PREDICATE :
        return new PredicateTransition(target, arg1, arg2, arg3 != 0);
      case Transition.PRECEDENCE:
        return new PrecedencePredicateTransition(target, arg1);
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

  // Determines if a particular serialized representation of an ATN supports
  // a particular feature, identified by the uuid used for serializing
  // the ATN at the time the feature was first introduced.
  //
  // feature is the uuid marking the first time the feature was
  // supported in the serialized ATN.
  // actualUuid is the uuid of the actual serialized ATN which is
  // currently being deserialized.
  // Return true if the actualUuid value represents a serialized ATN
  // at or after the feature identified by feature was introduced;
  // otherwise, false.
  static bool _isFeatureSupported(String feature, String actualUuid) {
    int featureIndex = _SUPPORTED_UUIDS.indexOf(feature);
    if (featureIndex < 0) {
      return false;
    }
    return _SUPPORTED_UUIDS.indexOf(actualUuid) >= featureIndex;
  }
}
