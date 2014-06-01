part of antlr4dart;

/// The embodiment of the adaptive LL(*), ALL(*), parsing strategy.
///
/// The basic complexity of the adaptive strategy makes it harder to
/// understand. We begin with ATN simulation to build paths in a
/// DFA. Subsequent prediction requests go through the DFA first. If
/// they reach a state without an edge for the current symbol, the
/// algorithm fails over to the ATN simulation to complete the DFA
/// path for the current input (until it finds a conflict state or
/// uniquely predicting state).
///
/// All of that is done without using the outer context because we
/// want to create a DFA that is not dependent upon the rule
/// invocation stack when we do a prediction.  One DFA works in all
/// contexts. We avoid using context not necessarily because it's
/// slower, although it can be, but because of the DFA caching
/// problem.  The closure routine only considers the rule invocation
/// stack created during prediction beginning in the decision rule.
/// For example, if prediction occurs without invoking another rule's
/// ATN, there are no context stacks in the configurations.
/// When lack of context leads to a conflict, we don't know if it's
/// an ambiguity or a weakness in the strong LL(*) parsing strategy
/// (versus full LL(*)).
///
/// When SLL yields a configuration set with conflict, we rewind the
/// input and retry the ATN simulation, this time using full outer
/// context without adding to the DFA. Configuration context
/// stacks will be the full invocation stacks from the start rule. If
/// we get a conflict using full context, then we can definitively
/// say we have a true ambiguity for that input sequence. If we don't
/// get a conflict, it implies that the decision is sensitive to the
/// outer context. (It is not context-sensitive in the sense of
/// context-sensitive grammars.)
///
/// The next time we reach this DFA state with an SLL conflict, through
/// DFA simulation, we will again retry the ATN simulation using full
/// context mode. This is slow because we can't save the results and have
/// to "interpret" the ATN each time we get that input.
///
/// CACHING FULL CONTEXT PREDICTIONS
///
/// We could cache results from full context to predicted
/// alternative easily and that saves a lot of time but doesn't work
/// in presence of predicates. The set of visible predicates from
/// the ATN start state changes depending on the context, because
/// closure can fall off the end of a rule. I tried to cache
/// tuples (stack context, semantic context, predicted alt) but it
/// was slower than interpreting and much more complicated. Also
/// required a huge amount of memory. The goal is not to create the
/// world's fastest parser anyway.
///
/// There is no strict ordering between the amount of input used by
/// SLL vs LL, which makes it really hard to build a cache for full
/// context. Let's say that we have input A B C that leads to an SLL
/// conflict with full context X.  That implies that using X we
/// might only use A B but we could also use A B C D to resolve
/// conflict.  Input A B C D could predict alternative 1 in one
/// position in the input and A B C E could predict alternative 2 in
/// another position in input.  The conflicting SLL configurations
/// could still be non-unique in the full context prediction, which
/// would lead us to requiring more input than the original A B C. To
/// make a prediction cache work, we have to track the exact input used
/// during the previous prediction. That amounts to a cache that maps X
/// to a specific DFA for that context.
///
/// Something should be done for left-recursive expression predictions.
/// They are likely LL(1) + pred eval. Easier to do the whole SLL unless
/// error and retry with full LL thing Sam does.
///
/// AVOIDING FULL CONTEXT PREDICTION
///
/// We avoid doing full context retry when the outer context is empty,
/// we did not dip into the outer context by falling off the end of the
/// decision state rule, or when we force SLL mode.
///
/// As an example of the not dip into outer context case, consider
/// as super constructor calls versus function calls. One grammar
/// might look like this:
///
///      ctorBody : '{' superCall? stat* '}' ;
///
/// Or, you might see something like:
///
///      stat : superCall ';' | expression ';' | ... ;
///
/// In both cases I believe that no closure operations will dip into the
/// outer context. In the first case ctorBody in the worst case will stop
/// at the '}'. In the 2nd case it should stop at the ';'. Both cases
/// should stay within the entry rule and not dip into the outer context.
///
/// PREDICATES
///
/// Predicates are always evaluated if present in either SLL or LL both.
/// SLL and LL simulation deals with predicates differently. SLL collects
/// predicates as it performs closure operations like ANTLR v3 did. It
/// delays predicate evaluation until it reaches and accept state. This
/// allows us to cache the SLL ATN simulation whereas, if we had evaluated
/// predicates on-the-fly during closure, the DFA state configuration sets
/// would be different and we couldn't build up a suitable DFA.
///
/// When building a DFA accept state during ATN simulation, we evaluate
/// any predicates and return the sole semantically valid alternative. If
/// there is more than 1 alternative, we report an ambiguity. If there are
/// 0 alternatives, we throw an exception. Alternatives without predicates
/// act like they have true predicates. The simple way to think about it
/// is to strip away all alternatives with false predicates and choose the
/// minimum alternative that remains.
///
/// When we start in the DFA and reach an accept state that's predicated,
/// we test those and return the minimum semantically viable
/// alternative. If no alternatives are viable, we throw an exception.
///
/// During full LL ATN simulation, closure always evaluates predicates and
/// on-the-fly. This is crucial to reducing the configuration set size
/// during closure. It hits a landmine when parsing with the Dart grammar,
/// for example, without this on-the-fly evaluation.
///
/// SHARING DFA
///
/// All instances of the same parser share the same decision DFAs through
/// a static field. Each instance gets its own ATN simulator but they
/// share the same decisionToDFA field. They also share a
/// PredictionContextCache object that makes sure that all
/// PredictionContext objects are shared among the DFA states. This makes
/// a big size difference.
class ParserAtnSimulator extends AtnSimulator {

  static bool _debug = false;
  static bool _debug_list_atn_decisions = false;
  static bool _dfa_debug = false;
  static bool _retry_debug = false;

  final Parser _parser;

  final List<Dfa> _decisionToDfa;

  // Each prediction operation uses a cache for merge of prediction contexts.
  // Don't keep around as it wastes huge amounts of memory. DoubleKeyMap
  // isn't synchronized but we're ok since two threads shouldn't reuse same
  // parser/atnsim object because it can only handle one input at a time.
  // This maps graphs a and b to merged result c. (a,b)->c. We can avoid
  // the merge if we ever see a and b again.  Note that (b,a)->c should
  // also be examined during cache lookup.
  DoubleKeyMap<PredictionContext,PredictionContext,PredictionContext> _mergeCache;

  TokenSource _input;
  int _startIndex;
  ParserRuleContext _outerContext;

  /// SLL, LL, or LL + exact ambig detection?
  PredictionMode predictionMode = PredictionMode.LL;

  ParserAtnSimulator(this._parser,
                     Atn atn,
                     this._decisionToDfa,
                     PredictionContextCache sharedContextCache)
      : super(atn, sharedContextCache);

  void reset() {}

  int adaptivePredict(TokenSource input,
                      int decision,
                      ParserRuleContext outerContext) {
    if (_debug || _debug_list_atn_decisions)  {
      print("adaptivePredict decision ${decision}exec lookAhead(1)==${getLookaheadName(input)}"
        " line ${input.lookToken(1).line}:${input.lookToken(1).charPositionInLine}");
    }
    _input = input;
    _startIndex = input.index;
    _outerContext = outerContext;
    Dfa dfa = _decisionToDfa[decision];
    int m = input.mark;
    int index = input.index;
    try {
      DfaState s0;
      if (dfa.isPrecedenceDfa) {
        // the start state for a precedence DFA depends on the current
        // parser precedence, and is provided by a DFA method.
        s0 = dfa.getPrecedenceStartState(_parser.precedence);
      } else {
        // the start state for a "regular" DFA is just s0
        s0 = dfa.s0;
      }
      if (s0 == null) {
        if (outerContext == null) outerContext = RuleContext.EMPTY;
        if (_debug || _debug_list_atn_decisions)  {
          print("predictATN decision ${dfa.decision}"
                     " exec lookAhead(1)==${getLookaheadName(input)}"
                     ", outerContext=${outerContext.toString(_parser)}");
        }

        // If this is not a precedence Dfa, we check the ATN start state
        // to determine if this ATN start state is the decision for the
        // closure block that determines whether a precedence rule
        // should continue or complete.
        if (!dfa.isPrecedenceDfa && dfa.atnStartState is StarLoopEntryState) {
          if ((dfa.atnStartState as StarLoopEntryState).precedenceRuleDecision) {
            dfa.isPrecedenceDfa = true;
          }
        }

        bool fullCtx = false;
        AtnConfigSet s0_closure = _computeStartState(dfa.atnStartState, RuleContext.EMPTY, fullCtx);

        if (dfa.isPrecedenceDfa) {
          // If this is a precedence DFA, we use applyPrecedenceFilter
          // to convert the computed start state to a precedence start
          // state. We then use Dfa.setPrecedenceStartState to set the
          // appropriate start state for the precedence level rather
          // than simply setting Dfa.s0.
          s0_closure = _applyPrecedenceFilter(s0_closure);
          s0 = _addDfaState_(dfa, new DfaState.config(s0_closure));
          dfa.setPrecedenceStartState(_parser.precedence, s0);
        } else {
          s0 = _addDfaState_(dfa, new DfaState.config(s0_closure));
          dfa.s0 = s0;
        }
        //dfa.s0 = _addDfaState_(dfa, new DfaState.config(s0_closure));
      }
      // We can start with an existing DFA
      int alt = _execAtn(dfa, s0, input, index, outerContext);
      if (_debug) print("DFA after predictATN: ${dfa.toString(_parser.tokenNames)}");
      return alt;
    } finally {
      // wack cache after each prediction
      _mergeCache = null;
      input.seek(index);
      input.release(m);
    }
  }

  String getRuleName(int index) {
    if (_parser != null && index >= 0)
      return _parser.ruleNames[index];
    return "<rule $index>";
  }

  String getTokenName(int t) {
    if (t == Token.EOF) return "EOF";
    List<String> tokensNames = _parser.tokenNames;
    if (_parser != null &&  tokensNames != null) {
      if (t >= tokensNames.length) {
        print("$t ttype out of range: $tokensNames");
        print(((_parser.inputSource) as CommonTokenSource).tokens);
      } else {
        return "${tokensNames[t]}<$t>";
      }
    }
    return t.toString();
  }

  String getLookaheadName(TokenSource input) {
    return getTokenName(input.lookAhead(1));
  }

  /// Used for debugging in adaptivePredict around execAtn but I cut
  /// it out for clarity now that alg. works well. We can leave this
  /// "dead" code for a bit.
  void dumpDeadEndConfigs(NoViableAltException nvae) {
    print("dead end configs: ");
    for (AtnConfig c in nvae.deadEndConfigs) {
      String trans = "no edges";
      if (c.state.numberOfTransitions > 0) {
        Transition t = c.state.transition(0);
        if (t is AtomTransition) {
          trans = "Atom ${getTokenName(t.especialLabel)}";
        } else if (t is SetTransition) {
          bool not = t is NotSetTransition;
          trans = "${(not?"~":"")}Set ${t.set}";
        }
      }
      print("${c.toString(_parser, true)}:$trans");
    }
  }

  // This method transforms the start state computed by
  // _computeStartState to the special start state used by a
  // precedence DFA for a particular precedence value. The transformation
  // process applies the following changes to the start state's configuration
  //  set.
  //
  // Evaluate the precedence predicates for each configuration using
  // SemanticContext.evalPrecedence.
  // Remove all configurations which predict an alternative greater than
  // 1, for which another configuration that predicts alternative 1 is in the
  // same ATN state. This transformation is valid for the following reasons:
  //
  // The closure block cannot contain any epsilon transitions which bypass
  // the body of the closure, so all states reachable via alternative 1 are
  // part of the precedence alternatives of the transformed left-recursive
  // rule.
  // The "primary" portion of a left recursive rule cannot contain an
  // epsilon transition, so the only way an alternative other than 1 can exist
  // in a state that is also reachable via alternative 1 is by nesting calls
  // to the left-recursive rule, with the outer calls not being at the
  // preferred precedence level.
  //
  // configs is the configuration set computed by
  // _computeStartState as the start state for the DFA.
  // Return the transformed configuration set representing the start state
  // for a precedence DFA at a particular precedence level (determined by
  // calling Parser.precedence.
  AtnConfigSet _applyPrecedenceFilter(AtnConfigSet configs) {
    Set<int> statesFromAlt1 = new HashSet<int>();
    AtnConfigSet configSet = new AtnConfigSet(configs.fullCtx);
    for (AtnConfig config in configs) {
      // handle alt 1 first
      if (config.alt != 1) continue;
      SemanticContext updatedContext = config.semanticContext.evalPrecedence(_parser, _outerContext);
      if (updatedContext == null) continue;
      statesFromAlt1.add(config.state.stateNumber);
      if (updatedContext != config.semanticContext) {
        configSet.add(new AtnConfig.from(config, semanticContext:updatedContext), _mergeCache);
      } else {
        configSet.add(config, _mergeCache);
      }
    }
    for (AtnConfig config in configs) {
      if (config.alt == 1) continue;
      if (statesFromAlt1.contains(config.state.stateNumber)) {
        // eliminated
        continue;
      }
      configSet.add(config, _mergeCache);
    }
    return configSet;
  }

  // Performs ATN simulation to compute a predicted alternative based
  // upon the remaining input, but also updates the DFA cache to avoid
  // having to traverse the ATN again for the same input sequence.
  //
  // There are some key conditions we're looking for after computing a new
  // set of ATN configs (proposed DFA state):
  // * if the set is empty, there is no viable alternative for current symbol
  // * does the state uniquely predict an alternative?
  // * does the state have a conflict that would prevent us from putting it
  //   on the work list?
  //
  // We also have some key operations to do:
  // * add an edge from previous DFA state to potentially new DFA state, D,
  //   upon current symbol but only if adding to work list, which means in all
  //   cases except no viable alternative (and possibly non-greedy decisions?)
  // * collecting predicates and adding semantic context to DFA accept states
  // * adding rule context to context-sensitive DFA accept states
  // * consuming an input symbol
  // * reporting a conflict
  // * reporting an ambiguity
  // * reporting a context sensitivity
  // * reporting insufficient predicates
  //
  // cover these cases:
  // * dead end
  // * single alt
  // * single alt + preds
  // * conflict
  // * conflict + preds
  int _execAtn(Dfa dfa,
               DfaState s0,
               TokenSource input,
               int startIndex,
               ParserRuleContext outerContext) {
    if (_debug || _debug_list_atn_decisions) {
      print("_execATN decision ${dfa.decision}"
                 " exec lookAhead(1)==${getLookaheadName(input)}"
                 " line ${input.lookToken(1).line}:${input.lookToken(1).charPositionInLine}");
    }
    DfaState previousD = s0;
    if (_debug) print("s0 = $s0");
    int t = input.lookAhead(1);
    while (true) { // while more work
      DfaState D = _getExistingTargetState(previousD, t);
      if (D == null) {
        D = _computeTargetState(dfa, previousD, t);
      }
      if (D == AtnSimulator.ERROR) {
        // if any configs in previous dipped into outer context, that
        // means that input up to t actually finished entry rule
        // at least for SLL decision. Full LL doesn't dip into outer
        // so don't need special case.
        // We will get an error no matter what so delay until after
        // decision; better error message. Also, no reachable target
        // ATN states in SLL implies LL will also get nowhere.
        // If conflict in states that dip out, choose min since we
        // will get error no matter what.
        NoViableAltException e = _noViableAlt(input, outerContext, previousD.configs, startIndex);
        input.seek(startIndex);
        int alt = _getSynValidOrSemInvalidAltThatFinishedDecisionEntryRule(previousD.configs, outerContext);
        if (alt != Atn.INVALID_ALT_NUMBER) {
          return alt;
        }
        throw e;
      }
      if (D.requiresFullContext && predictionMode != PredictionMode.SLL) {
        BitSet conflictingAlts = null;
        if (D.predicates!=null) {
          if (_debug) print("DFA state has preds in DFA sim LL failover");
          int conflictIndex = input.index;
          if (conflictIndex != startIndex) {
            input.seek(startIndex);
          }
          conflictingAlts = _evalSemanticContext(D.predicates, outerContext, true);
          if (conflictingAlts.cardinality == 1) {
            if (_debug) print("Full LL avoided");
            return conflictingAlts.nextSetBit(0);
          }
          if (conflictIndex != startIndex) {
            // restore the index so reporting the fallback to full
            // context occurs with the index at the correct spot
            input.seek(conflictIndex);
          }
        }
        if (_dfa_debug) print("ctx sensitive state $outerContext in $D");
        bool fullCtx = true;
        var s0_closure = _computeStartState(dfa.atnStartState, outerContext, fullCtx);
        _reportAttemptingFullContext(dfa, conflictingAlts, D.configs, startIndex, input.index);
        int alt = _execAtnWithFullContext(dfa, D, s0_closure, input, startIndex, outerContext);
        return alt;
      }
      if (D.isAcceptState) {
        if (D.predicates == null) {
          return D.prediction;
        }
        int stopIndex = input.index;
        input.seek(startIndex);
        BitSet alts = _evalSemanticContext(D.predicates, outerContext, true);
        switch (alts.cardinality) {
        case 0:
          throw _noViableAlt(input, outerContext, D.configs, startIndex);
        case 1:
          return alts.nextSetBit(0);
        default:
          // report ambiguity after predicate evaluation to make sure the correct
          // set of ambig alts is reported.
          _reportAmbiguity(dfa, D, startIndex, stopIndex, false, alts, D.configs);
          return alts.nextSetBit(0);
        }
      }
      previousD = D;
      if (t != IntSource.EOF) {
        input.consume();
        t = input.lookAhead(1);
      }
    }
  }

  // Get an existing target state for an edge in the DFA. If the target state
  // for the edge has not yet been computed or is otherwise not available,
  // this method returns null.
  //
  // previousD  is the current DFA state.
  // t is the next input symbol
  // Return The existing target DFA state for the given input symbol
  // t, or null if the target state for this edge is not already cached
  DfaState _getExistingTargetState(DfaState previousD, int t) {
    List<DfaState> edges = previousD.edges;
    if (edges == null || t + 1 < 0 || t + 1 >= edges.length) {
      return null;
    }
    return edges[t + 1];
  }

  // Compute a target state for an edge in the DFA, and attempt to add the
  // computed state and corresponding edge to the DFA.
  //
  // dfa is the DFA
  // previousD is the current DFA state.
  // t is the next input symbol.
  //
  // Return the computed target DFA state for the given input symbol
  // t. If t does not lead to a valid DFA state, this method
  // returns AtnSimulator.ERROR.
  DfaState _computeTargetState(Dfa dfa, DfaState previousD, int t) {
    AtnConfigSet reach = _computeReachSet(previousD.configs, t, false);
    if (reach == null) {
      _addDfaEdge(dfa, previousD, t, AtnSimulator.ERROR);
      return AtnSimulator.ERROR;
    }
    // create new target state; we'll add to DFA after it's complete
    DfaState D = new DfaState.config(reach);
    int predictedAlt = _getUniqueAlt(reach);
    if (_debug) {
      Iterable<BitSet> altSubSets = PredictionMode.getConflictingAltSubsets(reach);
      print("SLL altSubSets=$altSubSets"
                 ", configs=$reach"
                 ", predict=$predictedAlt, allSubsetsConflict="
                 "${PredictionMode.allSubsetsConflict(altSubSets)}, conflictingAlts="
                 "${_getConflictingAlts(reach)}");
    }

    if (predictedAlt != Atn.INVALID_ALT_NUMBER) {
      // NO CONFLICT, UNIQUELY PREDICTED ALT
      D.isAcceptState = true;
      D.configs.uniqueAlt = predictedAlt;
      D.prediction = predictedAlt;
    } else if (PredictionMode.hasSllConflictTerminatingPrediction(predictionMode, reach)) {
      // MORE THAN ONE VIABLE ALTERNATIVE
      D.configs._conflictingAlts = _getConflictingAlts(reach);
      D.requiresFullContext = true;
      // in SLL-only mode, we will stop at this state and return the minimum alt
      D.isAcceptState = true;
      D.prediction = D.configs._conflictingAlts.nextSetBit(0);
    }

    if ( D.isAcceptState && D.configs.hasSemanticContext) {
      _predicateDfaState(D, atn.getDecisionState(dfa.decision));
      if (D.predicates != null) {
        D.prediction = Atn.INVALID_ALT_NUMBER;
      }
    }
    // all adds to dfa are done after we've created full D state
    D = _addDfaEdge(dfa, previousD, t, D);
    return D;
  }

  void _predicateDfaState(DfaState dfaState, DecisionState decisionState) {
    // We need to test all predicates, even in DFA states that
    // uniquely predict alternative.
    int nalts = decisionState.numberOfTransitions;
    // Update DFA so reach becomes accept state with (predicate,alt)
    // pairs if preds found for conflicting alts
    BitSet altsToCollectPredsFrom = _getConflictingAltsOrUniqueAlt(dfaState.configs);
    List<SemanticContext> altToPred = _getPredsForAmbigAlts(altsToCollectPredsFrom, dfaState.configs, nalts);
    if (altToPred != null) {
      dfaState.predicates = _getPredicatePredictions(altsToCollectPredsFrom, altToPred);
      dfaState.prediction = Atn.INVALID_ALT_NUMBER; // make sure we use preds
    } else {
      // There are preds in configs but they might go away
      // when OR'd together like {p}? || NONE == NONE. If neither
      // alt has preds, resolve to min alt
      dfaState.prediction = altsToCollectPredsFrom.nextSetBit(0);
    }
  }

  // comes back with reach.uniqueAlt set to a valid alt
  int _execAtnWithFullContext(Dfa dfa,
                              DfaState D, // how far we got before failing over
                              AtnConfigSet s0,
                              TokenSource input, int startIndex,
                              ParserRuleContext outerContext) {
    if (_debug || _debug_list_atn_decisions) {
      print("execAtnWithFullContext $s0");
    }
    bool fullCtx = true;
    bool foundExactAmbig = false;
    AtnConfigSet reach = null;
    AtnConfigSet previous = s0;
    input.seek(startIndex);
    int t = input.lookAhead(1);
    int predictedAlt;
    while (true) { // while more work
      reach = _computeReachSet(previous, t, fullCtx);
      if (reach == null) {
        // if any configs in previous dipped into outer context, that
        // means that input up to t actually finished entry rule
        // at least for LL decision. Full LL doesn't dip into outer
        // so don't need special case.
        // We will get an error no matter what so delay until after
        // decision; better error message. Also, no reachable target
        // ATN states in SLL implies LL will also get nowhere.
        // If conflict in states that dip out, choose min since we
        // will get error no matter what.
        NoViableAltException e = _noViableAlt(input, outerContext, previous, startIndex);
        input.seek(startIndex);
        int alt = _getSynValidOrSemInvalidAltThatFinishedDecisionEntryRule(previous, outerContext);
        if (alt != Atn.INVALID_ALT_NUMBER) {
          return alt;
        }
        throw e;
      }
      Iterable<BitSet> altSubSets = PredictionMode.getConflictingAltSubsets(reach);
      if (_debug) {
        print("LL altSubSets=$altSubSets"
                   ", predict=${PredictionMode.getUniqueAlt(altSubSets)}"
                   ", resolvesToJustOneViableAlt="
                   "${PredictionMode.resolvesToJustOneViableAlt(altSubSets)}");
      }
      reach.uniqueAlt = _getUniqueAlt(reach);
      // unique prediction?
      if (reach.uniqueAlt != Atn.INVALID_ALT_NUMBER) {
        predictedAlt = reach.uniqueAlt;
        break;
      }
      if (predictionMode != PredictionMode.LL_EXACT_AMBIG_DETECTION) {
        predictedAlt = PredictionMode.resolvesToJustOneViableAlt(altSubSets);
        if (predictedAlt != Atn.INVALID_ALT_NUMBER) {
          break;
        }
      } else {
        // In exact ambiguity mode, we never try to terminate early.
        // Just keeps scarfing until we know what the conflict is
        if (PredictionMode.allSubsetsConflict(altSubSets) &&
           PredictionMode.allSubsetsEqual(altSubSets)) {
          foundExactAmbig = true;
          predictedAlt = PredictionMode.getSingleViableAlt(altSubSets);
          break;
        }
        // else there are multiple non-conflicting subsets or
        // we're not sure what the ambiguity is yet.
        // So, keep going.
      }
      previous = reach;
      if (t != IntSource.EOF) {
        input.consume();
        t = input.lookAhead(1);
      }
    }
    // If the configuration set uniquely predicts an alternative,
    // without conflict, then we know that it's a full LL decision
    // not SLL.
    if (reach.uniqueAlt != Atn.INVALID_ALT_NUMBER) {
      _reportContextSensitivity(dfa, predictedAlt, reach, startIndex, input.index);
      return predictedAlt;
    }

    // We do not check predicates here because we have checked them
    // on-the-fly when doing full context prediction.
    //
    // In non-exact ambiguity detection mode, we might actually be able to
    // detect an exact ambiguity, but I'm not going to spend the cycles
    // needed to check. We only emit ambiguity warnings in exact ambiguity
    // mode.
    //
    // For example, we might know that we have conflicting configurations.
    // But, that does not mean that there is no way forward without a
    // conflict. It's possible to have nonconflicting alt subsets as in:
    //
    // LL altSubSets=[{1, 2}, {1, 2}, {1}, {1, 2}]
    //
    // from
    //
    //   [(17,1,[5 $]), (13,1,[5 10 $]), (21,1,[5 10 $]), (11,1,[$]),
    //   (13,2,[5 10 $]), (21,2,[5 10 $]), (11,2,[$])]
    //
    // In this case, (17,1,[5 $]) indicates there is some next sequence that
    // would resolve this without conflict to alternative 1. Any other viable
    // next sequence, however, is associated with a conflict.  We stop
    // looking for input because no amount of further lookahead will alter
    // the fact that we should predict alternative 1.  We just can't say for
    // sure that there is an ambiguity without looking further.
    _reportAmbiguity(dfa, D, startIndex, input.index, foundExactAmbig, null, reach);
    return predictedAlt;
  }

  int _getSynValidOrSemInvalidAltThatFinishedDecisionEntryRule(AtnConfigSet configs,
                                                               ParserRuleContext outerContext) {
    Pair<AtnConfigSet,AtnConfigSet> sets = _splitAccordingToSemanticValidity(configs, outerContext);
    AtnConfigSet semValidConfigs = sets.a;
    AtnConfigSet semInvalidConfigs = sets.b;
    int alt = _getAltThatFinishedDecisionEntryRule(semValidConfigs);
    // semantically/syntactically viable path exists
    if (alt != Atn.INVALID_ALT_NUMBER) {
      return alt;
    }
    // Is there a syntactically valid path with a failed pred?
    if (!semInvalidConfigs.isEmpty) {
      alt = _getAltThatFinishedDecisionEntryRule(semInvalidConfigs);
      // syntactically viable path exists
      if (alt != Atn.INVALID_ALT_NUMBER) {
        return alt;
      }
    }
    return Atn.INVALID_ALT_NUMBER;
  }

  // Walk the list of configurations and split them according to
  // those that have preds evaluating to true/false.  If no pred, assume
  // true pred and include in succeeded set.  Returns Pair of sets.
  //
  // Create a new set so as not to alter the incoming parameter.
  //
  // Assumption: the input stream has been restored to the starting point
  // prediction, which is where predicates need to evaluate.
  Pair<AtnConfigSet,AtnConfigSet> _splitAccordingToSemanticValidity(AtnConfigSet configs,
                                                                    ParserRuleContext outerContext) {
    AtnConfigSet succeeded = new AtnConfigSet(configs.fullCtx);
    AtnConfigSet failed = new AtnConfigSet(configs.fullCtx);;
    for (AtnConfig c in configs) {
      if (c.semanticContext != SemanticContext.NONE ) {
        bool predicateEvaluationResult = c.semanticContext.eval(_parser, outerContext);
        if (predicateEvaluationResult) {
          succeeded.add(c);
        } else {
          failed.add(c);
        }
      } else {
        succeeded.add(c);
      }
    }
    return new Pair(succeeded, failed);
  }

  AtnConfigSet _computeReachSet(AtnConfigSet closure, int t, bool fullCtx) {
    if (_debug) print("in computeReachSet, starting closure: $closure");
    if (_mergeCache == null) {
      _mergeCache = new DoubleKeyMap<PredictionContext, PredictionContext, PredictionContext>();
    }
    AtnConfigSet intermediate = new AtnConfigSet(fullCtx);


    // Configurations already in a rule stop state indicate reaching the end
    // of the decision rule (local context) or end of the start rule (full
    // context). Once reached, these configurations are never updated by a
    // closure operation, so they are handled separately for the performance
    // advantage of having a smaller intermediate set when calling closure.
    //
    // For full-context reach operations, separate handling is required to
    // ensure that the alternative matching the longest overall sequence is
    // chosen when multiple such configurations can match the input.
    List<AtnConfig> skippedStopStates = null;
    // First figure out where we can reach on input t

    for (AtnConfig c in closure) {
      if (_debug) print("testing ${getTokenName(t)} at ${c.toString()}");
      if (c.state is RuleStopState) {
        assert(c.context.isEmpty);
        if (fullCtx || t == IntSource.EOF) {
          if (skippedStopStates == null) {
            skippedStopStates = new List<AtnConfig>();
          }
          skippedStopStates.add(c);
        }
        continue;
      }

      int n = c.state.numberOfTransitions;
      for (int ti = 0; ti < n; ti++) {  // for each transition
        Transition trans = c.state.transition(ti);
        AtnState target = _getReachableTarget(trans, t);
        if (target != null) {
          intermediate.add(new AtnConfig.from(c, state:target), _mergeCache);
        }
      }
    }

    // Now figure out where the reach operation can take us...
    AtnConfigSet reach = null;
    // This block optimizes the reach operation for intermediate sets which
    // trivially indicate a termination state for the overall
    // adaptivePredict operation.
    //
    // The conditions assume that intermediate
    // contains all configurations relevant to the reach set, but this
    // condition is not true when one or more configurations have been
    // withheld in skippedStopStates, or when the current symbol is EOF.
    if (skippedStopStates == null && t != Token.EOF) {
      if (intermediate.length == 1) {
        // Don't pursue the closure if there is just one state.
        // It can only have one alternative; just add to result
        // Also don't pursue the closure if there is unique alternative
        // among the configurations.
        reach = intermediate;
      } else if (_getUniqueAlt(intermediate) != Atn.INVALID_ALT_NUMBER) {
        // Also don't pursue the closure if there is unique alternative
        // among the configurations.
        reach = intermediate;
      }
    }
    // If the reach set could not be trivially determined, perform a closure
    // operation on the intermediate set to compute its initial value.
    if (reach == null) {
      reach = new AtnConfigSet(fullCtx);
      Set<AtnConfig> closureBusy = new HashSet<AtnConfig>();
      bool treatEofAsEpsilon = t == Token.EOF;
      for (AtnConfig c in intermediate) {
        _closure(c, reach, closureBusy, false, fullCtx, treatEofAsEpsilon);
      }
    }
    if (t == IntSource.EOF) {
      // After consuming EOF no additional input is possible, so we are
      // only interested in configurations which reached the end of the
      // decision rule (local context) or end of the start rule (full
      // context). Update reach to contain only these configurations. This
      // handles both explicit EOF transitions in the grammar and implicit
      // EOF transitions following the end of the decision or start rule.
      //
      // When reach==intermediate, no closure operation was performed. In
      // this case, removeAllConfigsNotInRuleStopState needs to check for
      // reachable rule stop states as well as configurations already in
      // a rule stop state.
      //
      // This is handled before the configurations in skippedStopStates,
      // because any configurations potentially added from that list are
      // already guaranteed to meet this condition whether or not it's
      // required.
      reach = _removeAllConfigsNotInRuleStopState(reach, reach == intermediate);
    }
    // If skippedStopStates is not null, then it contains at least one
    // configuration. For full-context reach operations, these
    // configurations reached the end of the start rule, in which case we
    // only add them back to reach if no configuration during the current
    // closure operation reached such a state. This ensures adaptivePredict
    // chooses an alternative matching the longest overall sequence when
    // multiple alternatives are viable.
    if (skippedStopStates != null &&
        (!fullCtx || !PredictionMode.hasConfigInRuleStopState(reach))) {
      assert(!skippedStopStates.isEmpty);
      for (AtnConfig c in skippedStopStates) {
        reach.add(c, _mergeCache);
      }
    }
    if (reach.isEmpty) return null;
    return reach;
  }

  // Return a configuration set containing only the configurations from
  // configs which are in a RuleStopState. If all configurations
  // in configs are already in a rule stop state, this
  // method simply returns configs.
  //
  // When lookToEndOfRule is true, this method uses
  // Atn.nextTokens for each configuration in configs which is
  // not already in a rule stop state to see if a rule stop state is reachable
  // from the configuration via epsilon-only transitions.
  //
  // configs the configuration set to update.
  // lookToEndOfRule when true, this method checks for rule stop states
  // reachable by epsilon-only transitions from each configuration in
  // configs.
  //
  // Return configs if all configurations in configs are in a
  // rule stop state, otherwise return a new configuration set containing only
  // the configurations from configs which are in a rule stop state.
  AtnConfigSet _removeAllConfigsNotInRuleStopState(AtnConfigSet configs, bool lookToEndOfRule) {
    if (PredictionMode.allConfigsInRuleStopStates(configs)) {
      return configs;
    }
    AtnConfigSet result = new AtnConfigSet(configs.fullCtx);
    for (AtnConfig config in configs) {
      if (config.state is RuleStopState) {
        result.add(config, _mergeCache);
        continue;
      }
      if (lookToEndOfRule && config.state.onlyHasEpsilonTransitions) {
        IntervalSet nextTokens = atn.nextTokensInSameRule(config.state);
        if (nextTokens.contains(Token.EPSILON)) {
          AtnState endOfRuleState = atn.ruleToStopState[config.state.ruleIndex];
          result.add(new AtnConfig.from(config, state:endOfRuleState), _mergeCache);
        }
      }
    }
    return result;
  }

  AtnConfigSet _computeStartState(AtnState p,
                                  RuleContext ctx,
                                  bool fullCtx) {
    // always at least the implicit call to start rule
    PredictionContext initialContext = PredictionContext.fromRuleContext(atn, ctx);
    AtnConfigSet configs = new AtnConfigSet(fullCtx);
    for (int i = 0; i < p.numberOfTransitions; i++) {
      AtnState target = p.transition(i).target;
      AtnConfig c = new AtnConfig(target, i+1, initialContext);
      Set<AtnConfig> closureBusy = new HashSet<AtnConfig>();
      _closure(c, configs, closureBusy, true, fullCtx, false);
    }
    return configs;
  }

  AtnState _getReachableTarget(Transition trans, int ttype) {
    if (trans.matches(ttype, 0, atn.maxTokenType)) {
      return trans.target;
    }
    return null;
  }

  List<SemanticContext> _getPredsForAmbigAlts(BitSet ambigAlts,
                                              AtnConfigSet configs,
                                              int nalts) {
    // REACH=[1|1|[]|0:0, 1|2|[]|0:1]
    // altToPred starts as an array of all null contexts. The entry at index i
    // corresponds to alternative i. altToPred[i] may have one of three values:
    //   1. null: no AtnConfig c is found such that c.alt == i
    //   2. SemanticContext.NONE: At least one AtnConfig c exists such that
    //      c.alt == i and c.semanticContext == SemanticContext.NONE. In other words,
    //      alt i has at least one unpredicated config.
    //   3. Non-NONE Semantic Context: There exists at least one, and for all
    //      AtnConfig c such that c.alt == i, c.semanticContext != SemanticContext.NONE.
    //
    // From this, it is clear that NONE || anything == NONE.
    List<SemanticContext> altToPred = new List<SemanticContext>(nalts + 1);
    for (AtnConfig c in configs) {
      if (ambigAlts.get(c.alt)) {
        altToPred[c.alt] = SemanticContext.or(altToPred[c.alt], c.semanticContext);
      }
    }
    int nPredAlts = 0;
    for (int i = 1; i <= nalts; i++) {
      if (altToPred[i] == null) {
        altToPred[i] = SemanticContext.NONE;
      } else if (altToPred[i] != SemanticContext.NONE) {
        nPredAlts++;
      }
    }
    // nonambig alts are null in altToPred
    if (nPredAlts == 0) altToPred = null;
    if (_debug) print("getPredsForAmbigAlts result $altToPred");
    return altToPred;
  }

  List<PredPrediction> _getPredicatePredictions(BitSet ambigAlts,
                                                List<SemanticContext> altToPred) {
    List<PredPrediction> pairs = new List<PredPrediction>();
    bool containsPredicate = false;
    for (int i = 1; i < altToPred.length; i++) {
      SemanticContext pred = altToPred[i];
      // unpredicated is indicated by SemanticContext.NONE
      assert(pred != null);
      if (ambigAlts != null && ambigAlts.get(i)) {
        pairs.add(new PredPrediction(pred, i));
      }
      if ( pred!=SemanticContext.NONE ) containsPredicate = true;
    }
    if (!containsPredicate) pairs = null;
    return pairs;
  }

  int _getAltThatFinishedDecisionEntryRule(AtnConfigSet configs) {
    IntervalSet alts = new IntervalSet();
    for (AtnConfig c in configs) {
      if (c.reachesIntoOuterContext>0
          || (c.state is RuleStopState && c.context.hasEmptyPath)) {
        alts.addSingle(c.alt);
      }
    }
    if (alts.length == 0) return Atn.INVALID_ALT_NUMBER;
    return alts.minElement;
  }

  // Look through a list of predicate/alt pairs, returning alts for the
  // pairs that win. A NONE predicate indicates an alt containing an
  // unpredicated config which behaves as "always true." If !complete
  // then we stop at the first predicate that evaluates to true. This
  // includes pairs with null predicates.
  BitSet _evalSemanticContext(List<PredPrediction> predPredictions,
                              ParserRuleContext outerContext,
                              bool complete) {
    BitSet predictions = new BitSet();
    for (PredPrediction pair in predPredictions) {
      if (pair.pred == SemanticContext.NONE) {
        predictions.set(pair.alt, true);
        if (!complete) break;
        continue;
      }
      bool predicateEvaluationResult = pair.pred.eval(_parser, outerContext);
      if (_debug || _dfa_debug) {
        print("eval pred $pair=${predicateEvaluationResult}");
      }
      if ( predicateEvaluationResult ) {
        if (_debug || _dfa_debug) print("PREDICT ${pair.alt}");
        predictions.set(pair.alt, true);
        if (!complete) break;
      }
    }
    return predictions;
  }

  void _closure(AtnConfig config,
                AtnConfigSet configs,
                Set<AtnConfig> closureBusy,
                bool collectPredicates,
                bool fullCtx,
                bool treatEofAsEpsilon) {
    final int initialDepth = 0;
    _closureCheckingStopState(config,
        configs, closureBusy, collectPredicates, fullCtx, initialDepth, treatEofAsEpsilon);
    assert(!fullCtx || !configs.dipsIntoOuterContext);
  }

  void _closureCheckingStopState(AtnConfig config,
                                 AtnConfigSet configs,
                                 Set<AtnConfig> closureBusy,
                                 bool collectPredicates,
                                 bool fullCtx,
                                 int depth,
                                 bool treatEofAsEpsilon) {
    if (_debug) print("_closure(${config.toString(_parser,true)})");
    if (config.state is RuleStopState) {
      // We hit rule end. If we have context info, use it
      // run thru all possible stack tops in ctx
      if (!config.context.isEmpty) {
        for (int i = 0; i < config.context.length; i++) {
          if (config.context.getReturnState(i) == PredictionContext.EMPTY_RETURN_STATE) {
            if (fullCtx) {
              configs.add(new AtnConfig.from(config,
                  state:config.state, context:PredictionContext.EMPTY), _mergeCache);
              continue;
            } else {
              // we have no context info, just chase follow links (if greedy)
              if (_debug) print("FALLING off rule ${getRuleName(config.state.ruleIndex)}");
              _closure_(config, configs, closureBusy, collectPredicates, fullCtx, depth, treatEofAsEpsilon);
            }
            continue;
          }
          AtnState returnState = atn.states[config.context.getReturnState(i)];
          PredictionContext newContext = config.context.getParent(i); // "pop" return state
          AtnConfig c = new AtnConfig(returnState, config.alt, newContext, config.semanticContext);
          // While we have context to pop back from, we may have
          // gotten that context AFTER having falling off a rule.
          // Make sure we track that we are now out of context.
          c.reachesIntoOuterContext = config.reachesIntoOuterContext;
          assert (depth > -pow(2, 53));
          _closureCheckingStopState(c, configs, closureBusy, collectPredicates, fullCtx, depth - 1, treatEofAsEpsilon);
        }
        return;
      } else if (fullCtx) {
        // reached end of start rule
        configs.add(config, _mergeCache);
        return;
      } else {
        // else if we have no context info, just chase follow links (if greedy)
        if (_debug) print("FALLING off rule ${getRuleName(config.state.ruleIndex)}");
      }
    }
    _closure_(config, configs, closureBusy, collectPredicates, fullCtx, depth, treatEofAsEpsilon);
  }

  // Do the actual work of walking epsilon edges.
  void _closure_(AtnConfig config,
                 AtnConfigSet configs,
                 Set<AtnConfig> closureBusy,
                 bool collectPredicates,
                 bool fullCtx,
                 int depth,
                 bool treatEofAsEpsilon) {
    AtnState p = config.state;
    // optimization
    if (!p.onlyHasEpsilonTransitions) {
      configs.add(config, _mergeCache);
    }
    for (int i = 0; i < p.numberOfTransitions; i++) {
      Transition t = p.transition(i);
      bool continueCollecting = (t is! ActionTransition) && collectPredicates;
      AtnConfig c = _getEpsilonTarget(config, t, continueCollecting, depth == 0, fullCtx, treatEofAsEpsilon);
      if (c != null) {
        if (!t.isEpsilon && !closureBusy.add(c)) {
          // avoid infinite recursion for EOF* and EOF+
          // continue;
          continue;
        }
        int newDepth = depth;
        if (config.state is RuleStopState) {
          assert(!fullCtx);
          // target fell off end of rule; mark resulting c as having dipped into outer context
          // We can't get here if incoming config was rule stop and we had context
          // track how far we dip into outer context.  Might
          // come in handy and we avoid evaluating context dependent
          // preds if this is > 0.
          if (!closureBusy.add(c)) {
            // avoid infinite recursion for right-recursive rules
            continue;
          }
          c.reachesIntoOuterContext++;
          // TODO: can remove? only care when we add to set per middle of this method
          configs.dipsIntoOuterContext = true;
          assert(newDepth > -pow(2, 53));
          newDepth--;
          if (_debug) print("dips into outer ctx: $c");
        } else if (t is RuleTransition) {
          // latch when newDepth goes negative - once we step out of the entry context we can't return
          if (newDepth >= 0) newDepth++;
        }
        _closureCheckingStopState(c, configs, closureBusy, continueCollecting, fullCtx, newDepth, treatEofAsEpsilon);
      }
    }
  }

  AtnConfig _getEpsilonTarget(AtnConfig config,
                              Transition t,
                              bool collectPredicates,
                              bool inContext,
                              bool fullCtx,
                              bool treatEofAsEpsilon) {
    switch (t.serializationType) {
      case Transition.RULE:
        return _ruleTransition(config, t);
      case Transition.PRECEDENCE:
        return _precedenceTransition(config, t, collectPredicates, inContext, fullCtx);
      case Transition.PREDICATE:
        return _predTransition(config, t, collectPredicates, inContext, fullCtx);
      case Transition.ACTION:
        return _actionTransition(config, t);
      case Transition.EPSILON:
        return new AtnConfig.from(config, state:t.target);
      case Transition.ATOM:
      case Transition.RANGE:
      case Transition.SET:
        // EOF transitions act like epsilon transitions after the first EOF
        // transition is traversed
        if (treatEofAsEpsilon) {
          if (t.matches(Token.EOF, 0, 1)) {
            return new AtnConfig.from(config, state:t.target);
          }
        }
        return null;
      default: return null;
    }
  }

  AtnConfig _precedenceTransition(AtnConfig config,
                                  PrecedencePredicateTransition pt,
                                  bool collectPredicates,
                                  bool inContext,
                                  bool fullCtx) {
    if (_debug) {
      print("PRED (collectPredicates=$collectPredicates) ${pt.precedence}>=_p, ctx dependent=true");
      if (_parser != null) {
        print("context surrounding pred is ${_parser.ruleInvocationStack}");
      }
    }
    AtnConfig c = null;
    if (collectPredicates && inContext) {
      if (fullCtx) {
        // In full context mode, we can evaluate predicates on-the-fly
        // during closure, which dramatically reduces the size of
        // the config sets. It also obviates the need to test predicates
        // later during conflict resolution.
        int currentPosition = _input.index;
        _input.seek(_startIndex);
        bool predSucceeds = pt.predicate.eval(_parser, _outerContext);
        _input.seek(currentPosition);
        if ( predSucceeds ) {
          c = new AtnConfig.from(config, state:pt.target); // no pred context
        }
      } else {
        SemanticContext newSemCtx = SemanticContext.and(config.semanticContext, pt.predicate);
        c = new AtnConfig.from(config, state:pt.target, semanticContext:newSemCtx);
      }
    } else {
      c = new AtnConfig.from(config, state:pt.target);
    }
    if (_debug) print("config from pred transition=$c");
    return c;
  }

  AtnConfig _actionTransition(AtnConfig config, ActionTransition t) {
    if (_debug) print("ACTION edge ${t.ruleIndex}:${t.actionIndex}");
    return new AtnConfig.from(config, state:t.target);
  }

  AtnConfig _predTransition(AtnConfig config,
                            PredicateTransition pt,
                            bool collectPredicates,
                            bool inContext,
                            bool fullCtx) {
    if (_debug) {
      print("PRED (collectPredicates=$collectPredicates) "
          "${pt.ruleIndex}:${pt.predIndex}, ctx dependent=${pt.isCtxDependent}");
      if (_parser != null) {
          print("context surrounding pred is ${_parser.ruleInvocationStack}");
      }
    }
    AtnConfig c = null;
    if (collectPredicates &&
       (!pt.isCtxDependent || (pt.isCtxDependent && inContext))) {
      if (fullCtx) {
        // In full context mode, we can evaluate predicates on-the-fly
        // during closure, which dramatically reduces the size of
        // the config sets. It also obviates the need to test predicates
        // later during conflict resolution.
        int currentPosition = _input.index;
        _input.seek(_startIndex);
        bool predSucceeds = pt.predicate.eval(_parser, _outerContext);
        _input.seek(currentPosition);
        if (predSucceeds) {
          c = new AtnConfig.from(config, state:pt.target); // no pred context
        }
      } else {
        var newSemCtx = SemanticContext.and(config.semanticContext, pt.predicate);
        c = new AtnConfig.from(config, state:pt.target, semanticContext:newSemCtx);
      }
    } else {
      c = new AtnConfig.from(config, state:pt.target);
    }
    if (_debug) print("config from pred transition=$c");
    return c;
  }

  AtnConfig _ruleTransition(AtnConfig config, RuleTransition t) {
    if (_debug) {
      print("CALL rule ${getRuleName(t.target.ruleIndex)}, ctx=${config.context}");
    }
    AtnState returnState = t.followState;
    var newContext = SingletonPredictionContext.create(config.context, returnState.stateNumber);
    return new AtnConfig.from(config, state:t.target, context:newContext);
  }

  BitSet _getConflictingAlts(AtnConfigSet configs) {
    Iterable<BitSet> altsets = PredictionMode.getConflictingAltSubsets(configs);
    return PredictionMode.getAlts(altsets);
  }

  // If we have another state associated with conflicting
  // alternatives, we should keep going. For example, the following grammar
  //
  // s : (ID | ID ID?) ';' ;

  // When the ATN simulation reaches the state before ';', it has a DFA
  // state that looks like: [12|1|[], 6|2|[], 12|2|[]]. Naturally
  // 12|1|[] and 12|2|[] conflict, but we cannot stop processing this node
  // because alternative to has another way to continue, via [6|2|[]].
  // The key is that we have a single state that has config's only associated
  // with a single alternative, 2, and crucially the state transitions
  // among the configurations are all non-epsilon transitions. That means
  // we don't consider any conflicts that include alternative 2. So, we
  // ignore the conflict between alts 1 and 2. We ignore a set of
  // conflicting alts when there is an intersection with an alternative
  // associated with a single alt state in the state->config-list map.
  //
  // It's also the case that we might have two conflicting configurations but
  // also a 3rd nonconflicting configuration for a different alternative:
  // [1|1|[], 1|2|[], 8|3|[]]. This can come about from grammar:
  //
  // a : A | A | A B ;
  //
  // After matching input A, we reach the stop state for rule A, state 1.
  // State 8 is the state right before B. Clearly alternatives 1 and 2
  // conflict and no amount of further lookahead will separate the two.
  // However, alternative 3 will be able to continue and so we do not
  // stop working on this state. In the previous example, we're concerned
  // with states associated with the conflicting alternatives. Here alt
  // 3 is not associated with the conflicting configs, but since we can continue
  // looking for input reasonably, I don't declare the state done. We
  // ignore a set of conflicting alts when we have an alternative
  // that we still need to pursue.
  BitSet _getConflictingAltsOrUniqueAlt(AtnConfigSet configs) {
    BitSet conflictingAlts;
    if (configs.uniqueAlt != Atn.INVALID_ALT_NUMBER) {
      conflictingAlts = new BitSet();
      conflictingAlts.set(configs.uniqueAlt, true);
    } else {
      conflictingAlts = configs._conflictingAlts;
    }
    return conflictingAlts;
  }

  NoViableAltException _noViableAlt(TokenSource input,
                                    ParserRuleContext outerContext,
                                    AtnConfigSet configs,
                                    int startIndex) {
    return new NoViableAltException(_parser, input,
        input.get(startIndex), input.lookToken(1), configs, outerContext);
  }

  static int _getUniqueAlt(AtnConfigSet configs) {
    int alt = Atn.INVALID_ALT_NUMBER;
    for (AtnConfig c in configs) {
      if ( alt == Atn.INVALID_ALT_NUMBER ) {
        alt = c.alt; // found first alt
      } else if (c.alt != alt) {
        return Atn.INVALID_ALT_NUMBER;
      }
    }
    return alt;
  }

  // Add an edge to the DFA, if possible. This method calls
  // _addDfaState_ to ensure the to state is present in the
  // DFA. If from is null, or if t is outside the
  // range of edges that can be represented in the DFA tables, this method
  // returns without adding the edge to the DFA.
  //
  // If to is null, this method returns null.
  // Otherwise, this method returns the DfaState returned by calling
  // _addDfaState_ for the to state.
  //
  // dfa is the DFA
  // from is the source state for the edge
  // t is the input symbol
  // to is the target state for the edge
  DfaState _addDfaEdge(Dfa dfa,
                       DfaState from,
                       int t,
                       DfaState to) {
    if (_debug) {
      print("EDGE $from -> $to upon ${getTokenName(t)}");
    }
    if (to == null) return null;
    to = _addDfaState_(dfa, to); // used existing if possible not incoming
    if (from == null || t < -1 || t > atn.maxTokenType) {
      return to;
    }
    if (from.edges == null) {
      from.edges = new List<DfaState>(atn.maxTokenType + 1 + 1);
    }
    from.edges[t+1] = to; // connect
    if (_debug) {
      print("DFA=\n${dfa.toString(_parser != null ? _parser.tokenNames:null)}");
    }
    return to;
  }

  // Add state D to the DFA if it is not already present, and return
  // the actual instance stored in the DFA. If a state equivalent to D
  // is already in the DFA, the existing state is returned. Otherwise this
  // method returns D after adding it to the DFA.
  //
  // If D is ERROR, this method returns ERROR and
  // does not change the DFA.
  //
  // dfa is the dfa
  // D is the DFA state to add
  // Return the state stored in the DFA. This will be either the existing
  // state if D is already in the DFA, or D itself if the
  // state was not already present.
  DfaState _addDfaState_(Dfa dfa, DfaState D) {
    if (D == AtnSimulator.ERROR) return D;
    DfaState existing = dfa.states[D];
    if (existing != null) return existing;
    D.stateNumber = dfa.states.length;
    if (!D.configs.isReadonly) {
      D.configs.optimizeConfigs(this);
      D.configs.isReadonly = true;
    }
    dfa.states[D] = D;
    if (_debug) print("adding new DFA state: $D");
    return D;
  }

  void _reportAttemptingFullContext(Dfa dfa,
                                    BitSet conflictingAlts,
                                    AtnConfigSet configs,
                                    int startIndex,
                                    int stopIndex) {
    if (_debug || _retry_debug) {
      Interval interval = Interval.of(startIndex, stopIndex);
      print("reportAttemptingFullContext decision=${dfa.decision}"
        ":$configs, input=${_parser.inputSource.getTextIn(interval)}");
      }
      if (_parser != null) _parser.errorListenerDispatch
        .reportAttemptingFullContext(_parser, dfa, startIndex, stopIndex, conflictingAlts, configs);
    }

  void _reportContextSensitivity(Dfa dfa,
                                 int prediction,
                                 AtnConfigSet configs,
                                 int startIndex,
                                 int stopIndex) {
    if (_debug || _retry_debug) {
      Interval interval = Interval.of(startIndex, stopIndex);
      print("reportContextSensitivity decision=${dfa.decision}"
        ":$configs, input=${_parser.inputSource.getTextIn(interval)}");
    }
    if (_parser != null) _parser.errorListenerDispatch
      .reportContextSensitivity(_parser, dfa, startIndex, stopIndex, prediction, configs);
  }

  // If context sensitive parsing, we know it's ambiguity not conflict.
  void _reportAmbiguity(Dfa dfa,
                        DfaState D,
                        int startIndex,
                        int stopIndex,
                        bool exact,
                        BitSet ambigAlts,
                        AtnConfigSet configs) {
    if (_debug || _retry_debug) {
      Interval interval = Interval.of(startIndex, stopIndex);
      print("reportAmbiguity $ambigAlts:$configs, "
        "input=${_parser.inputSource.getTextIn(interval)}");
    }
    if (_parser != null) _parser.errorListenerDispatch
      .reportAmbiguity(_parser, dfa, startIndex, stopIndex, exact, ambigAlts, configs);
  }
}
