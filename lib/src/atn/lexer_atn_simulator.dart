part of antlr4dart;

/**
 * "dup" of ParserInterpreter
 */
class LexerAtnSimulator extends AtnSimulator {
  static bool _debug = false;
  static bool _dfa_debug = false;

  static const int MIN_DFA_EDGE = 0;
  static const int MAX_DFA_EDGE = 127; // forces unicode to stay in ATN

  final Lexer _recog;

  // The current token's starting index into the character source.
  // Shared across DFA to ATN simulation in case the ATN fails and the
  // DFA did not have a previous accept state. In this case, we use the
  // ATN-generated exception object.
  int _startIndex = -1;

  int _mode = Lexer._DEFAULT_MODE;

  // Used during DFA/ATN exec to record the most recent accept configuration info.
  final _SimState _prevAccept = new _SimState();

  /*
   * Line number 1..n within the input.
   */
  int line = 1;

  /*
   * The index of the character relative to the beginning of the line 0..n-1.
   */
  int charPositionInLine = 0;

  final List<Dfa> decisionToDfa;

  static int match_calls = 0;

  LexerAtnSimulator(Atn atn,
                    this.decisionToDfa,
                    PredictionContextCache sharedContextCache,
                    [this._recog]) : super(atn, sharedContextCache);

  void copyState(LexerAtnSimulator simulator) {
    charPositionInLine = simulator.charPositionInLine;
    line = simulator.line;
    _mode = simulator._mode;
    _startIndex = simulator._startIndex;
  }

  int match(CharSource input, int mode) {
    match_calls++;
    _mode = mode;
    int mark = input.mark;
    try {
      _startIndex = input.index;
      _prevAccept._reset();
      Dfa dfa = decisionToDfa[mode];
      if (dfa.s0 == null) {
        return _matchAtn(input);
      } else {
        return _execAtn(input, dfa.s0);
      }
    } finally {
      input.release(mark);
    }
  }

  void reset() {
    _prevAccept._reset();
    _startIndex = -1;
    line = 1;
    charPositionInLine = 0;
    _mode = Lexer._DEFAULT_MODE;
  }

  Dfa getDfa(int mode) => decisionToDfa[mode];

  /**
   * Get the text matched so far for the current token.
   */
  String getText(CharSource input) {
    // index is first lookahead char, don't include.
    return input.getText(Interval.of(_startIndex, input.index - 1));
  }

  void consume(CharSource input) {
    int curChar = input.lookAhead(1);
    if (curChar == '\n'.codeUnitAt(0)) {
      line++;
      charPositionInLine = 0;
    } else {
      charPositionInLine++;
    }
    input.consume();
  }

  String getTokenName(int t) {
    if (t == -1) return "EOF";
    return "'${new String.fromCharCode(t)}'";
  }

  int _matchAtn(CharSource input) {
    AtnState startState = atn.modeToStartState[_mode];
    if (_debug) print("_matchAtn mode $_mode start: $startState");
    int old_mode = _mode;
    AtnConfigSet s0_closure = _computeStartState(input, startState);
    bool suppressEdge = s0_closure.hasSemanticContext;
    s0_closure.hasSemanticContext = false;
    DfaState next = _addDfaState(s0_closure);
    if (!suppressEdge) {
      decisionToDfa[_mode].s0 = next;
    }
    int predict = _execAtn(input, next);
    if (_debug) print("DFA after _matchAtn: ${decisionToDfa[old_mode].toLexerString()}");
    return predict;
  }

  int _execAtn(CharSource input, DfaState ds0) {
    if (_debug) print("start state closure=${ds0.configs}");
    int t = input.lookAhead(1);
    DfaState s = ds0; // s is current/from DFA state
    while (true) { // while more work
      if (_debug) print("execATN loop starting closure: ${s.configs}");
      // As we move src->trg, src->trg, we keep track of the previous trg to
      // avoid looking up the DFA state again, which is expensive.
      // If the previous target was already part of the DFA, we might
      // be able to avoid doing a reach operation upon t. If s!=null,
      // it means that semantic predicates didn't prevent us from
      // creating a DFA state. Once we know s!=null, we check to see if
      // the DFA state has an edge already for t. If so, we can just reuse
      // it's configuration set; there's no point in re-computing it.
      // This is kind of like doing DFA simulation within the ATN
      // simulation because DFA simulation is really just a way to avoid
      // computing reach/closure sets. Technically, once we know that
      // we have a previously added DFA state, we could jump over to
      // the DFA simulator. But, that would mean popping back and forth
      // a lot and making things more complicated algorithmically.
      // This optimization makes a lot of sense for loops within DFA.
      // A character will take us back to an existing DFA state
      // that already has lots of edges out of it. e.g., .* in comments.
      DfaState target = _getExistingTargetState(s, t);
      if (target == null) {
        target = _computeTargetState(input, s, t);
      }
      if (target == AtnSimulator.ERROR) break;
      if (target.isAcceptState) {
        _captureSimState(_prevAccept, input, target);
        if (t == IntSource.EOF) break;
      }
      if (t != IntSource.EOF) {
        consume(input);
        t = input.lookAhead(1);
      }
      s = target; // flip; current DFA target becomes new src/from state
    }
    return _failOrAccept(_prevAccept, input, s.configs, t);
  }

  // Get an existing target state for an edge in the DFA. If the target state
  // for the edge has not yet been computed or is otherwise not available,
  // this method returns null.
  //
  // s is the current DFA state
  // is t the next input symbol
  // Return the existing target DFA state for the given input symbol
  // t, or null if the target state for this edge is not
  // already cached
  DfaState _getExistingTargetState(DfaState s, int t) {
    if (s.edges == null || t < MIN_DFA_EDGE || t > MAX_DFA_EDGE) return null;
    DfaState target = s.edges[t - MIN_DFA_EDGE];
    if (_debug && target != null) {
      print("reuse state ${s.stateNumber} edge to ${target.stateNumber}");
    }
    return target;
  }

  // Compute a target state for an edge in the DFA, and attempt to add the
  // computed state and corresponding edge to the DFA.
  //
  // input is the input source
  // s is the current DFA state
  // t is he next input symbol
  //
  // Return the computed target DFA state for the given input symbol
  // t. If t does not lead to a valid DFA state, this method
  // returns ERROR.
  DfaState _computeTargetState(CharSource input, DfaState s, int t) {
    AtnConfigSet reach = new AtnConfigSet();
    // if we don't find an existing DFA state
    // Fill reach starting from closure, following t transitions
    _getReachableConfigSet(input, s.configs, reach, t);
    if (reach.isEmpty) { // we got nowhere on t from s
      if (!reach.hasSemanticContext) {
       // we got nowhere on t, don't throw out this knowledge; it'd
        // cause a failover from DFA later.
        __addDfaEdge(s, t, AtnSimulator.ERROR);
      }
      // stop when we can't match any more char
      return AtnSimulator.ERROR;
    }
    // Add an edge from s to target DFA found/created for reach
    return _addDfaEdge(s, t, reach);
  }

  int _failOrAccept(_SimState prevAccept,
                    CharSource input,
                    AtnConfigSet reach,
                    int t) {
    if (prevAccept._dfaState != null) {
      LexerActionExecutor lexerActionExecutor = prevAccept._dfaState.lexerActionExecutor;
      _accept(input, lexerActionExecutor, _startIndex,
          prevAccept._index, prevAccept._line, prevAccept._charPos);
      return prevAccept._dfaState.prediction;
    } else {
      // if no accept and EOF is first char, return EOF
      if (t == IntSource.EOF && input.index == _startIndex) {
        return Token.EOF;
      }
      throw new LexerNoViableAltException(_recog, input, _startIndex, reach);
    }
  }

  // Given a starting configuration set, figure out all ATN configurations
  // we can reach upon input t. Parameter reach is a return
  // parameter.
  void _getReachableConfigSet(CharSource input, AtnConfigSet closure, AtnConfigSet reach, int t) {
    // this is used to skip processing for configs which have a lower priority
    // than a config that already reached an accept state for the same rule
    int skipAlt = Atn.INVALID_ALT_NUMBER;
    for (AtnConfig c in closure) {
      bool currentAltReachedAcceptState = c.alt == skipAlt;
      if (currentAltReachedAcceptState && (c as LexerAtnConfig).hasPassedThroughNonGreedyDecision) {
        continue;
      }
      if (_debug) {
        print("testing ${getTokenName(t)} at ${c.toString(_recog, true)}");
      }
      int n = c.state.numberOfTransitions;
      for (int ti = 0; ti < n; ti++) {               // for each transition
        Transition trans = c.state.transition(ti);
        AtnState target = _getReachableTarget(trans, t);
        if (target != null) {
          LexerActionExecutor lexerActionExecutor = (c as LexerAtnConfig).lexerActionExecutor;
          if (lexerActionExecutor != null) {
            lexerActionExecutor = lexerActionExecutor.fixOffsetBeforeMatch(input.index - _startIndex);
          }
          if (_closure(input, new LexerAtnConfig.from(c,
              target, actionExecutor:lexerActionExecutor), reach, currentAltReachedAcceptState, true)) {
            // any remaining configs for this alt have a lower priority than
            // the one that just reached an accept state.
            skipAlt = c.alt;
            break;
          }
        }
      }
    }
  }

  void _accept(CharSource input, LexerActionExecutor lexerActionExecutor, int startIndex, int index, int line, int charPos) {
    if (_debug) {
      print("ACTION $lexerActionExecutor");
    }
    // seek to after last char in token
    input.seek(index);
    this.line = line;
    charPositionInLine = charPos;
    if (input.lookAhead(1) != IntSource.EOF) consume(input);
    if (lexerActionExecutor != null && _recog != null) {
      lexerActionExecutor.execute(_recog, input, startIndex);
    }
  }

  AtnState _getReachableTarget(Transition trans, int t) {
    if (trans.matches(t, Lexer.MIN_CHAR_VALUE, Lexer.MAX_CHAR_VALUE + 1)) {
      return trans.target;
    }
    return null;
  }

  AtnConfigSet _computeStartState(CharSource input, AtnState p) {
    PredictionContext initialContext = PredictionContext.EMPTY;
    AtnConfigSet configs = new AtnConfigSet();
    for (int i = 0; i< p.numberOfTransitions; i++) {
      AtnState target = p.transition(i).target;
      LexerAtnConfig c = new LexerAtnConfig(target, i + 1, initialContext);
      _closure(input, c, configs, false, false);
    }
    return configs;
  }

  // Since the alternatives within any lexer decision are ordered by
  // preference, this method stops pursuing the closure as soon as an accept
  // state is reached. After the first accept state is reached by depth-first
  // search from config, all other (potentially reachable) states for
  // this rule would have a lower priority.
  //
  // Return true if an accept state is reached, otherwise false.
  bool _closure(CharSource input,
                LexerAtnConfig config,
                AtnConfigSet configs,
                bool currentAltReachedAcceptState,
                bool speculative) {
    if (_debug) {
      print("_closure(${config.toString(_recog, true)})");
    }
    if (config.state is RuleStopState) {
      if (_debug) {
        if (_recog != null) {
          print("closure at ${_recog.ruleNames[config.state.ruleIndex]} rule stop $config");
        } else {
          print("closure at rule stop $config");
        }
      }
      if (config.context == null || config.context.hasEmptyPath) {
        if (config.context == null || config.context.isEmpty) {
          configs.add(config);
          return true;
        } else {
          configs.add(new LexerAtnConfig.from(config, config.state, context:PredictionContext.EMPTY));
          currentAltReachedAcceptState = true;
        }
      }
      if (config.context != null && !config.context.isEmpty) {
        for (int i = 0; i < config.context.length; i++) {
          if (config.context.getReturnState(i) != PredictionContext.EMPTY_RETURN_STATE) {
            PredictionContext newContext = config.context.getParent(i); // "pop" return state
            AtnState returnState = atn.states[config.context.getReturnState(i)];
            LexerAtnConfig c = new LexerAtnConfig(returnState, config.alt, newContext);
            currentAltReachedAcceptState = _closure(input, c, configs, currentAltReachedAcceptState, speculative);
          }
        }
      }
      return currentAltReachedAcceptState;
    }
    // optimization
    if (!config.state.onlyHasEpsilonTransitions) {
      if (!currentAltReachedAcceptState || !config.hasPassedThroughNonGreedyDecision) {
        configs.add(config);
      }
    }
    AtnState p = config.state;
    for (int i = 0; i < p.numberOfTransitions; i++) {
      Transition t = p.transition(i);
      LexerAtnConfig c = _getEpsilonTarget(input, config, t, configs, speculative);
      if (c != null) {
        currentAltReachedAcceptState = _closure(input, c, configs, currentAltReachedAcceptState, speculative);
      }
    }
    return currentAltReachedAcceptState;
  }

  // side-effect: can alter configs.hasSemanticContext
  LexerAtnConfig _getEpsilonTarget(CharSource input,
                                   LexerAtnConfig config,
                                   Transition t,
                                   AtnConfigSet configs,
                                   bool speculative) {
    LexerAtnConfig c = null;
    switch (t.serializationType) {
      case Transition.RULE:
        var newContext = SingletonPredictionContext.create(
            config.context, (t as RuleTransition).followState.stateNumber);
        c = new LexerAtnConfig.from(config, t.target, context:newContext);
        break;
      case Transition.PRECEDENCE:
        throw new UnsupportedError("Precedence predicates are not supported in lexers.");
      case Transition.PREDICATE:
        // Track traversing semantic predicates. If we traverse,
        // we cannot add a DFA state for this "reach" computation
        // because the DFA would not test the predicate again in the
        // future. Rather than creating collections of semantic predicates
        // like v3 and testing them on prediction, v4 will test them on the
        // fly all the time using the ATN not the DFA. This is slower but
        // semantically it's not used that often. One of the key elements to
        // this predicate mechanism is not adding DFA states that see
        // predicates immediately afterwards in the ATN. For example,
        //
        //  a : ID {p1}? | ID {p2}? ;
        //
        // should create the start state for rule 'a' (to save start state
        // competition), but should not create target of ID state. The
        // collection of ATN states the following ID references includes
        // states reached by traversing predicates. Since this is when we
        // test them, we cannot cash the DFA state target of ID.
        PredicateTransition pt = t;
        if (_debug) {
          print("EVAL rule ${pt.ruleIndex}:${pt.predIndex}");
        }
        configs.hasSemanticContext = true;
        if (_evaluatePredicate(input, pt.ruleIndex, pt.predIndex, speculative)) {
          c = new LexerAtnConfig.from(config, t.target);
        }
        break;
      case Transition.ACTION:
        if (config.context == null || config.context.hasEmptyPath) {
          LexerActionExecutor lexerActionExecutor = LexerActionExecutor
              .append(config.lexerActionExecutor, atn.lexerActions[(t as ActionTransition).actionIndex]);
          c = new LexerAtnConfig.from(config, t.target, actionExecutor:lexerActionExecutor);
        } else {
          // ignore actions in referenced rules
          c = new LexerAtnConfig.from(config, t.target);
        }
        break;
      case Transition.EPSILON:
        c = new LexerAtnConfig.from(config, t.target);
        break;
    }
    return c;
  }

  // Evaluate a predicate specified in the lexer.
  //
  // If speculative is true, this method was called before
  // consume for the matched character. This method should call
  // consume before evaluating the predicate to ensure position
  // sensitive values, including Lexer.text, Lexer.line,
  // and Lexer.charPositionInLine, properly reflect the current
  // lexer state. This method should restore input and the simulator
  // to the original state before returning (i.e. undo the actions made by the
  // call to consume.
  //
  // input is he input source.
  // ruleIndex is the rule containing the predicate.
  // predIndex is the index of the predicate within the rule.
  // speculative true if the current index in input is
  // one character before the predicate's location.
  //
  // Return true if the specified predicate evaluates to true.
  bool _evaluatePredicate(CharSource input, int ruleIndex, int predIndex, bool speculative) {
    // assume true if no recognizer was provided
    if (_recog == null) return true;
    if (!speculative) {
      return _recog.sempred(null, ruleIndex, predIndex);
    }
    int savedCharPositionInLine = charPositionInLine;
    int savedLine = line;
    int index = input.index;
    int marker = input.mark;
    try {
      consume(input);
      return _recog.sempred(null, ruleIndex, predIndex);
    }
    finally {
      charPositionInLine = savedCharPositionInLine;
      line = savedLine;
      input.seek(index);
      input.release(marker);
    }
  }

  void _captureSimState(_SimState settings,
                        CharSource input,
                        DfaState dfaState) {
    settings._index = input.index;
    settings._line = line;
    settings._charPos = charPositionInLine;
    settings._dfaState = dfaState;
  }

  DfaState _addDfaEdge(DfaState from,
                       int t,
                       AtnConfigSet q) {
    // leading to this call, AtnConfigSet.hasSemanticContext is used as a
    // marker indicating dynamic predicate evaluation makes this edge
    // dependent on the specific input sequence, so the static edge in the
    // DFA should be omitted. The target DfaState is still created since
    // _execAtn has the ability to resynchronize with the DFA state cache
    // following the predicate evaluation step.
    //
    // TJP notes: next time through the DFA, we see a pred again and eval.
    // If that gets us to a previously created (but dangling) DFA
    // state, we can continue in pure DFA mode from there.
    bool suppressEdge = q.hasSemanticContext;
    q.hasSemanticContext = false;
    DfaState to = _addDfaState(q);
    if (suppressEdge) return to;
    __addDfaEdge(from, t, to);
    return to;
  }

  void __addDfaEdge(DfaState p, int t, DfaState q) {
    // Only track edges within the DFA bounds
    if (t < MIN_DFA_EDGE || t > MAX_DFA_EDGE) return;
    if (_debug) print("EDGE $p -> $q upon '${new String.fromCharCode(t)}'");
    Dfa dfa = decisionToDfa[_mode];
    if (p.edges == null) {
      //  make room for tokens 1..n and -1 masquerading as index 0
      p.edges = new List<DfaState>(MAX_DFA_EDGE-MIN_DFA_EDGE + 1);
    }
    p.edges[t - MIN_DFA_EDGE] = q; // connect
  }

  // Add a new DFA state if there isn't one with this set of
  // configurations already. This method also detects the first
  // configuration containing an ATN rule stop state. Later, when
  // traversing the DFA, we will know which rule to accept.
  DfaState _addDfaState(AtnConfigSet configs) {
    // the lexer evaluates predicates on-the-fly; by this point configs
    // should not contain any configurations with unevaluated predicates.
    assert(!configs.hasSemanticContext);
    DfaState proposed = new DfaState.config(configs);
    AtnConfig firstConfigWithRuleStopState = null;
    for (AtnConfig c in configs) {
      if (c.state is RuleStopState ) {
        firstConfigWithRuleStopState = c;
        break;
      }
    }
    if (firstConfigWithRuleStopState != null) {
      proposed.isAcceptState = true;
      proposed.lexerActionExecutor = (firstConfigWithRuleStopState as LexerAtnConfig).lexerActionExecutor;
      proposed.prediction = atn.ruleToTokenType[firstConfigWithRuleStopState.state.ruleIndex];
    }
    Dfa dfa = decisionToDfa[_mode];
    DfaState existing = dfa.states[proposed];
    if (existing != null) return existing;
    DfaState newState = proposed;
    newState.stateNumber = dfa.states.length;
    configs.isReadonly = true;
    newState.configs = configs;
    dfa.states[newState] = newState;
    return newState;
  }
}

// When we hit an accept state in either the DFA or the ATN, we
// have to notify the character source to start buffering characters
// via IntSource.mark and record the current state. The current sim state
// includes the current index into the input, the current line,
// and current character position in that line. Note that the Lexer is
// tracking the starting line and characterization of the token. These
// variables track the "state" of the simulator when it hits an accept state.
//
// We track these variables separately for the DFA and ATN simulation
// because the DFA simulation often has to fail over to the ATN
// simulation. If the ATN simulation fails, we need the DFA to fall
// back to its previously accepted state, if any. If the ATN succeeds,
// then the ATN does the accept and the DFA simulator that invoked it
// can simply return the predicted token type.
class _SimState {
  int _index = -1;
  int _line = 0;
  int _charPos = -1;
  DfaState _dfaState;

  void _reset() {
    _index = -1;
    _line = 0;
    _charPos = -1;
    _dfaState = null;
  }
}
