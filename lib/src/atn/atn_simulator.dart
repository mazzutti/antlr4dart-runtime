part of antlr4dart;

abstract class AtnSimulator {

  /// Must distinguish between missing edge and edge we know leads nowhere
  static final ERROR = new DfaState(pow(2, 53) - 1)..configs = new AtnConfigSet();

  final Atn atn;

  /// The context cache maps all [PredictionContext] objects that are `==`
  /// to a single cached copy. This cache is shared across all contexts
  /// in all [AtnConfig]s in all DFA states.  We rebuild each [AtnConfigSet]
  /// to use only cached nodes/graphs in `addDfaState`. We don't want to
  /// fill this during `closure` since there are lots of contexts that
  /// pop up but are not used ever again. It also greatly slows down `closure`.
  final PredictionContextCache sharedContextCache;

  AtnSimulator(this.atn, this.sharedContextCache);

  void reset();

  PredictionContext getCachedContext(PredictionContext context) {
    if (sharedContextCache == null) return context;
    var visited = new HashMap<PredictionContext, PredictionContext>();
    return PredictionContext
        .getCachedContext(context, sharedContextCache, visited);
  }

  /// Clear the DFA cache used by the current instance. Since the DFA cache may
  /// be shared by multiple ATN simulators, this method may affect the
  /// performance (but not accuracy) of other parsers which are being used
  /// concurrently.
  ///
  /// An [UnsupportedError] occurs if the current instance does not support
  /// clearing the DFA.
  void clearDfa() {
    throw new UnsupportedError(
        "This ATN simulator does not support clearing the DFA.");
  }

  static Atn deserialize(String data) => new AtnDeserializer().deserialize(data);
}

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
/// **CACHING FULL CONTEXT PREDICTIONS**
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
/// **AVOIDING FULL CONTEXT PREDICTION**
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
/// **PREDICATES**
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
/// **SHARING DFA**
///
/// All instances of the same parser share the same decision DFAs through
/// a static field. Each instance gets its own ATN simulator but they
/// share the same decisionToDFA field. They also share a
/// PredictionContextCache object that makes sure that all
/// PredictionContext objects are shared among the DFA states. This makes
/// a big size difference.
class ParserAtnSimulator extends AtnSimulator {

  final Parser parser;
  final List<Dfa> decisionToDfa;

  // Each prediction operation uses a cache for merge of prediction contexts.
  // Don't keep around as it wastes huge amounts of memory. DoubleKeyMap
  // isn't synchronized but we're ok since two threads shouldn't reuse same
  // parser/atnsim object because it can only handle one input at a time.
  // This maps graphs a and b to merged result c. (a,b)->c. We can avoid
  // the merge if we ever see a and b again.  Note that (b,a)->c should
  // also be examined during cache lookup.
  DoubleKeyMap _mergeCache;

  TokenSource _input;
  int _startIndex;
  ParserRuleContext _outerContext;

  /// SLL, LL, or LL + exact ambiguity detection?
  PredictionMode predictionMode = PredictionMode.LL;

  ParserAtnSimulator(this.parser,
                     Atn atn,
                     this.decisionToDfa,
                     PredictionContextCache sharedContextCache)
      : super(atn, sharedContextCache);

  void reset() {}

  int adaptivePredict(TokenSource tokenSource,
                      int decision,
                      ParserRuleContext outerContext) {
    _input = tokenSource;
    _startIndex = tokenSource.index;
    _outerContext = outerContext;
    Dfa dfa = decisionToDfa[decision];
    int m = tokenSource.mark;
    int index = _startIndex;
    try {
      DfaState s0;
      if (dfa.isPrecedenceDfa) {
        // the start state for a precedence DFA depends on the current
        // parser precedence, and is provided by a DFA method.
        s0 = dfa.getPrecedenceStartStateFor(parser.precedence);
      } else {
        // the start state for a "regular" DFA is just s0
        s0 = dfa.s0;
      }
      if (s0 == null) {
        if (outerContext == null) outerContext = RuleContext.EMPTY;
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
        var s0Closure = _computeStartState(
            dfa.atnStartState, RuleContext.EMPTY, fullCtx);
        if (dfa.isPrecedenceDfa) {
          // If this is a precedence DFA, we use applyPrecedenceFilter
          // to convert the computed start state to a precedence start
          // state. We then use Dfa.setPrecedenceStartState to set the
          // appropriate start state for the precedence level rather
          // than simply setting Dfa.s0.
          s0Closure = _applyPrecedenceFilter(s0Closure);
          s0 = _addDfaState_(dfa, new DfaState.config(s0Closure));
          dfa.setPrecedenceStartStateFor(parser.precedence, s0);
        } else {
          s0 = _addDfaState_(dfa, new DfaState.config(s0Closure));
          dfa.s0 = s0;
        }
      }
      // We can start with an existing DFA
      int alt = _execAtn(dfa, s0, tokenSource, index, outerContext);
      return alt;
    } finally {
      // wack cache after each prediction
      _mergeCache = null;
      tokenSource.seek(index);
      tokenSource.release(m);
    }
  }

  String getRuleName(int index) {
    return (parser != null && index >= 0)
        ? parser.ruleNames[index] : "<rule $index>";
  }

  String getTokenName(int token) {
    if (token == Token.EOF) return "EOF";
    List<String> tokensNames = parser.tokenNames;
    if (parser != null &&  tokensNames != null) {
      if (token >= tokensNames.length) {
        throw new RangeError("$token ttype out of range: $tokensNames");
      } else {
        return "${tokensNames[token]}<$token>";
      }
    }
    return token.toString();
  }

  String getLookaheadName(TokenSource tokenSource) {
    return getTokenName(tokenSource.lookAhead(1));
  }

  void clearDfa() {
    for (int d = 0; d < decisionToDfa.length; d++) {
      decisionToDfa[d] = new Dfa(atn.getDecisionState(d), d);
    }
  }

  // Used for debugging in adaptivePredict around execAtn but I cut
  // it out for clarity now that alg. works well. We can leave this
  // "dead" code for a bit.
  void _dumpDeadEndConfigs(NoViableAltException nvae) {
    print("dead end configs: ");
    for (AtnConfig c in nvae.deadEndConfigs) {
      String trans = "no edges";
      if (c.state.numberOfTransitions > 0) {
        Transition t = c.state.getTransition(0);
        if (t is AtomTransition) {
          trans = "Atom ${getTokenName(t.especialLabel)}";
        } else if (t is SetTransition) {
          bool not = t is NotSetTransition;
          trans = "${(not?"~":"")}Set ${t.set}";
        }
      }
      print("${c.toString(parser, true)}:$trans");
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
      var updatedContext =
          config.semanticContext.evalPrecedence(parser, _outerContext);
      if (updatedContext == null) continue;
      statesFromAlt1.add(config.state.stateNumber);
      if (updatedContext != config.semanticContext) {
        configSet.add(new AtnConfig.from(
            config, semanticContext:updatedContext), _mergeCache);
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
  //  * if the set is empty, there is no viable alternative for current symbol
  //  * does the state uniquely predict an alternative?
  //  * does the state have a conflict that would prevent us from putting it
  //    on the work list?
  //
  // We also have some key operations to do:
  //  * add an edge from previous DFA state to potentially new DFA state, D,
  //    upon current symbol but only if adding to work list, which means in all
  //    cases except no viable alternative (and possibly non-greedy decisions?)
  //  * collecting predicates and adding semantic context to DFA accept states
  //  * adding rule context to context-sensitive DFA accept states
  //  * consuming an input symbol
  //  * reporting a conflict
  //  * reporting an ambiguity
  //  * reporting a context sensitivity
  //  * reporting insufficient predicates
  //
  // cover these cases:
  //  * dead end
  //  * single alt
  //  * single alt + preds
  //  * conflict
  //  * conflict + preds
  int _execAtn(Dfa dfa,
               DfaState s0,
               TokenSource tokenSource,
               int startIndex,
               ParserRuleContext outerContext) {
    DfaState previousD = s0;
    int token = tokenSource.lookAhead(1);
    while (true) {
      DfaState state = _getExistingTargetState(previousD, token);
      if (state == null) state = _computeTargetState(dfa, previousD, token);
      if (state == AtnSimulator.ERROR) {
        // if any configs in previous dipped into outer context, that
        // means that input up to t actually finished entry rule
        // at least for SLL decision. Full LL doesn't dip into outer
        // so don't need special case.
        // We will get an error no matter what so delay until after
        // decision; better error message. Also, no reachable target
        // ATN states in SLL implies LL will also get nowhere.
        // If conflict in states that dip out, choose min since we
        // will get error no matter what.
        NoViableAltException e = _noViableAlt(
            tokenSource, outerContext, previousD.configs, startIndex);
        tokenSource.seek(startIndex);
        int alt = _getSynValidOrSemInvalidAlt(previousD.configs, outerContext);
        if (alt != Atn.INVALID_ALT_NUMBER) return alt;
        throw e;
      }
      if (state.requiresFullContext && predictionMode != PredictionMode.SLL) {
        BitSet conflictingAlts = null;
        if (state.predicates != null) {
          int conflictIndex = tokenSource.index;
          if (conflictIndex != startIndex) tokenSource.seek(startIndex);
          conflictingAlts = _evalSemanticContext(
              state.predicates, outerContext, true);
          if (conflictingAlts.cardinality == 1) {
            return conflictingAlts.nextSetBit(0);
          }
          if (conflictIndex != startIndex) {
            // restore the index so reporting the fallback to full
            // context occurs with the index at the correct spot
            tokenSource.seek(conflictIndex);
          }
        }
        bool fullCtx = true;
        var s0Closure = _computeStartState(
            dfa.atnStartState, outerContext, fullCtx);
        _reportAttemptingFullContext(
            dfa, conflictingAlts, state.configs, startIndex, tokenSource.index);
        int alt = _execAtnWithFullContext(
            dfa, state, s0Closure, tokenSource, startIndex, outerContext);
        return alt;
      }
      if (state.isAcceptState) {
        if (state.predicates == null) {
          return state.prediction;
        }
        int stopIndex = tokenSource.index;
        tokenSource.seek(startIndex);
        BitSet alts = _evalSemanticContext(state.predicates, outerContext, true);
        switch (alts.cardinality) {
          case 0: throw _noViableAlt(
                tokenSource, outerContext, state.configs, startIndex);
          case 1: return alts.nextSetBit(0);
          default:
            // report ambiguity after predicate evaluation to make sure the
            // correct set of ambig alts is reported.
            _reportAmbiguity(
                dfa, state, startIndex, stopIndex, false, alts, state.configs);
            return alts.nextSetBit(0);
        }
      }
      previousD = state;
      if (token != Token.EOF) {
        tokenSource.consume();
        token = tokenSource.lookAhead(1);
      }
    }
  }

  // Get an existing target state for an edge in the DFA. If the target state
  // for the edge has not yet been computed or is otherwise not available,
  // this method returns null.
  //
  // previousD  is the current DFA state.
  // token is the next input symbol
  // Return The existing target DFA state for the given input symbol
  // token, or null if the target state for this edge is not already cached
  DfaState _getExistingTargetState(DfaState previousD, int token) {
    List<DfaState> edges = previousD.edges;
    if (edges == null || token + 1 < 0 || token + 1 >= edges.length) {
      return null;
    }
    return edges[token + 1];
  }

  // Compute a target state for an edge in the DFA, and attempt to add the
  // computed state and corresponding edge to the DFA.
  //
  // dfa is the DFA
  // previousD is the current DFA state.
  // token is the next input symbol.
  //
  // Return the computed target DFA state for the given input symbol
  // token. If t does not lead to a valid DFA state, this method
  // returns AtnSimulator.ERROR.
  DfaState _computeTargetState(Dfa dfa, DfaState previousD, int token) {
    AtnConfigSet reach = _computeReachSet(previousD.configs, token, false);
    if (reach == null) {
      _addDfaEdge(dfa, previousD, token, AtnSimulator.ERROR);
      return AtnSimulator.ERROR;
    }
    // create new target state; we'll add to DFA after it's complete
    DfaState state = new DfaState.config(reach);
    int predictedAlt = _getUniqueAlt(reach);
    if (predictedAlt != Atn.INVALID_ALT_NUMBER) {
      // NO CONFLICT, UNIQUELY PREDICTED ALT
      state
          ..isAcceptState = true
          ..configs.uniqueAlt = predictedAlt
          ..prediction = predictedAlt;
    } else if (PredictionMode
        .hasSllConflictTerminatingPrediction(predictionMode, reach)) {
      // MORE THAN ONE VIABLE ALTERNATIVE
      state
          ..configs._conflictingAlts = _getConflictingAlts(reach)
          ..requiresFullContext = true
          // in SLL-only mode, we will stop at this state and return the
          // minimum alt
          ..isAcceptState = true
          ..prediction = state.configs._conflictingAlts.nextSetBit(0);
    }

    if ( state.isAcceptState && state.configs.hasSemanticContext) {
      _predicateDfaState(state, atn.getDecisionState(dfa.decision));
      if (state.predicates != null) {
        state.prediction = Atn.INVALID_ALT_NUMBER;
      }
    }
    // all adds to dfa are done after we've created full D state
    state = _addDfaEdge(dfa, previousD, token, state);
    return state;
  }

  void _predicateDfaState(DfaState dfaState, DecisionState decisionState) {
    // We need to test all predicates, even in DFA states that
    // uniquely predict alternative.
    int nalts = decisionState.numberOfTransitions;
    // Update DFA so reach becomes accept state with (predicate,alt)
    // pairs if preds found for conflicting alts
    var altsToCollect = _getConflictingAltsOrUniqueAlt(dfaState.configs);
    var altToPred = _getPredsForAmbigAlts(
        altsToCollect, dfaState.configs, nalts);
    if (altToPred != null) {
      dfaState
          ..predicates = _getPredicatePredictions(altsToCollect, altToPred)
          ..prediction = Atn.INVALID_ALT_NUMBER;
    } else {
      // There are preds in configs but they might go away
      // when OR'd together like {p}? || NONE == NONE. If neither
      // alt has preds, resolve to min alt
      dfaState.prediction = altsToCollect.nextSetBit(0);
    }
  }

  // comes back with reach.uniqueAlt set to a valid alt
  int _execAtnWithFullContext(Dfa dfa,
                              DfaState D, // how far we got before failing over
                              AtnConfigSet s0,
                              TokenSource input, int startIndex,
                              ParserRuleContext outerContext) {
    bool fullCtx = true;
    bool foundExactAmbig = false;
    AtnConfigSet reach = null;
    AtnConfigSet previous = s0;
    input.seek(startIndex);
    int token = input.lookAhead(1);
    int predictedAlt;
    while (true) { // while more work
      reach = _computeReachSet(previous, token, fullCtx);
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
        var e = _noViableAlt(input, outerContext, previous, startIndex);
        input.seek(startIndex);
        int alt = _getSynValidOrSemInvalidAlt(previous, outerContext);
        if (alt != Atn.INVALID_ALT_NUMBER) return alt;
        throw e;
      }
      var altSubSets = PredictionMode.getConflictingAltSubsets(reach);
      reach.uniqueAlt = _getUniqueAlt(reach);
      // unique prediction?
      if (reach.uniqueAlt != Atn.INVALID_ALT_NUMBER) {
        predictedAlt = reach.uniqueAlt;
        break;
      }
      if (predictionMode != PredictionMode.LL_EXACT_AMBIG_DETECTION) {
        predictedAlt = PredictionMode.resolvesToJustOneViableAlt(altSubSets);
        if (predictedAlt != Atn.INVALID_ALT_NUMBER) break;
      } else {
        // In exact ambiguity mode, we never try to terminate early.
        // Just keeps scarfing until we know what the conflict is
        if (PredictionMode.allSubsetsConflict(altSubSets)
            && PredictionMode.allSubsetsEqual(altSubSets)) {
          foundExactAmbig = true;
          predictedAlt = PredictionMode.getSingleViableAlt(altSubSets);
          break;
        }
        // else there are multiple non-conflicting subsets or
        // we're not sure what the ambiguity is yet.
        // So, keep going.
      }
      previous = reach;
      if (token != Token.EOF) {
        input.consume();
        token = input.lookAhead(1);
      }
    }
    // If the configuration set uniquely predicts an alternative,
    // without conflict, then we know that it's a full LL decision
    // not SLL.
    if (reach.uniqueAlt != Atn.INVALID_ALT_NUMBER) {
      _reportContextSensitivity(
          dfa, predictedAlt, reach, startIndex, input.index);
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
    // the fact that we should predict alternative 1. We just can't say for
    // sure that there is an ambiguity without looking further.
    _reportAmbiguity(
        dfa, D, startIndex, input.index, foundExactAmbig, null, reach);
    return predictedAlt;
  }

  int _getSynValidOrSemInvalidAlt(AtnConfigSet configs,
                                  ParserRuleContext outerContext) {
    var sets = _splitAccordingToSemValidity(configs, outerContext);
    AtnConfigSet semValidConfigs = sets.a;
    AtnConfigSet semInvalidConfigs = sets.b;
    int alt = _getAltThatFinishedDecisionEntryRule(semValidConfigs);
    // semantically/syntactically viable path exists
    if (alt != Atn.INVALID_ALT_NUMBER) return alt;
    // Is there a syntactically valid path with a failed pred?
    if (!semInvalidConfigs.isEmpty) {
      alt = _getAltThatFinishedDecisionEntryRule(semInvalidConfigs);
      // syntactically viable path exists
      if (alt != Atn.INVALID_ALT_NUMBER) return alt;
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
  Pair _splitAccordingToSemValidity(AtnConfigSet configs,
                                    ParserRuleContext outerContext) {
    AtnConfigSet succeeded = new AtnConfigSet(configs.fullCtx);
    AtnConfigSet failed = new AtnConfigSet(configs.fullCtx);;
    for (AtnConfig c in configs) {
      if (c.semanticContext != SemanticContext.NONE ) {
        bool predicate = c.semanticContext.eval(parser, outerContext);
        if (predicate) {
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
    if (_mergeCache == null) _mergeCache = new DoubleKeyMap();
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
      if (c.state is RuleStopState) {
        assert(c.context.isEmpty);
        if (fullCtx || t == Token.EOF) {
          if (skippedStopStates == null) {
            skippedStopStates = new List<AtnConfig>();
          }
          skippedStopStates.add(c);
        }
        continue;
      }

      int n = c.state.numberOfTransitions;
      for (int ti = 0; ti < n; ti++) {  // for each transition
        Transition trans = c.state.getTransition(ti);
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
    if (t == Token.EOF) {
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
  AtnConfigSet _removeAllConfigsNotInRuleStopState(AtnConfigSet configs,
                                                   bool lookToEndOfRule) {
    if (PredictionMode.allConfigsInRuleStopStates(configs)) return configs;
    AtnConfigSet result = new AtnConfigSet(configs.fullCtx);
    for (AtnConfig config in configs) {
      if (config.state is RuleStopState) {
        result.add(config, _mergeCache);
        continue;
      }
      if (lookToEndOfRule && config.state.onlyHasEpsilonTransitions) {
        IntervalSet nextTokens = atn.nextTokensInSameRule(config.state);
        if (nextTokens.contains(Token.EPSILON)) {
          AtnState end = atn.ruleToStopState[config.state.ruleIndex];
          result.add(new AtnConfig.from(config, state:end), _mergeCache);
        }
      }
    }
    return result;
  }

  AtnConfigSet _computeStartState(AtnState p,
                                  RuleContext ctx,
                                  bool fullCtx) {
    // always at least the implicit call to start rule
    var initialContext = new PredictionContext.fromRuleContext(atn, ctx);
    AtnConfigSet configs = new AtnConfigSet(fullCtx);
    for (int i = 0; i < p.numberOfTransitions; i++) {
      AtnState target = p.getTransition(i).target;
      AtnConfig c = new AtnConfig(target, i+1, initialContext);
      Set<AtnConfig> closureBusy = new HashSet<AtnConfig>();
      _closure(c, configs, closureBusy, true, fullCtx, false);
    }
    return configs;
  }

  AtnState _getReachableTarget(Transition trans, int ttype) {
    return trans.matches(ttype, 0, atn.maxTokenType) ? trans.target : null;
  }

  List<SemanticContext> _getPredsForAmbigAlts(BitSet ambigAlts,
                                              AtnConfigSet configs,
                                              int nalts) {
    // REACH=[1|1|[]|0:0, 1|2|[]|0:1]
    // altToPred starts as an array of all null contexts. The entry at index i
    // corresponds to alternative i. altToPred[i] may have one of three values:
    //   1. null: no AtnConfig c is found such that c.alt == i
    //   2. SemanticContext.NONE: At least one AtnConfig c exists such that
    //      c.alt == i and c.semanticContext == SemanticContext.NONE. In other
    //      words, alt i has at least one unpredicated config.
    //   3. Non-NONE Semantic Context: There exists at least one, and for all
    //      AtnConfig c such that c.alt == i,
    //      c.semanticContext != SemanticContext.NONE.
    //
    // From this, it is clear that NONE || anything == NONE.
    List<SemanticContext> altToPred = new List<SemanticContext>(nalts + 1);
    for (AtnConfig c in configs) {
      if (ambigAlts.get(c.alt)) {
        altToPred[c.alt] = SemanticContext.or(
            altToPred[c.alt], c.semanticContext);
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
    return altToPred;
  }

  List _getPredicatePredictions(BitSet ambigAlts,
                                List<SemanticContext> altToPred) {
    List<_PredPrediction> pairs = new List<_PredPrediction>();
    bool containsPredicate = false;
    for (int i = 1; i < altToPred.length; i++) {
      SemanticContext pred = altToPred[i];
      // unpredicated is indicated by SemanticContext.NONE
      assert(pred != null);
      if (ambigAlts != null && ambigAlts.get(i)) {
        pairs.add(new _PredPrediction(pred, i));
      }
      if (pred!=SemanticContext.NONE) containsPredicate = true;
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
  BitSet _evalSemanticContext(List<_PredPrediction> predPredictions,
                              ParserRuleContext outerContext,
                              bool complete) {
    BitSet predictions = new BitSet();
    for (_PredPrediction pair in predPredictions) {
      if (pair.pred == SemanticContext.NONE) {
        predictions.set(pair.alt, true);
        if (!complete) break;
        continue;
      }
      bool predicateEvaluationResult = pair.pred.eval(parser, outerContext);
      if ( predicateEvaluationResult ) {
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
    _closureCheckingStopState(config, configs, closureBusy,
        collectPredicates, fullCtx, initialDepth, treatEofAsEpsilon);
    assert(!fullCtx || !configs.dipsIntoOuterContext);
  }

  void _closureCheckingStopState(AtnConfig config,
                                 AtnConfigSet configs,
                                 Set<AtnConfig> closureBusy,
                                 bool collectPredicates,
                                 bool fullCtx,
                                 int depth,
                                 bool treatEofAsEpsilon) {
    if (config.state is RuleStopState) {
      // We hit rule end. If we have context info, use it
      // run thru all possible stack tops in ctx
      if (!config.context.isEmpty) {
        for (int i = 0; i < config.context.length; i++) {
          if (config.context.returnStateFor(i)
              == PredictionContext.EMPTY_RETURN_STATE) {
            if (fullCtx) {
              configs.add(new AtnConfig.from(config, state:config.state,
                  context:PredictionContext.EMPTY), _mergeCache);
              continue;
            } else {
              // we have no context info, just chase follow links (if greedy)
              _closure_(config, configs, closureBusy,
                  collectPredicates, fullCtx, depth, treatEofAsEpsilon);
            }
            continue;
          }
          AtnState returnState = atn.states[config.context.returnStateFor(i)];
          PredictionContext newContext = config.context.parentFor(i);
          AtnConfig c = new AtnConfig(
              returnState, config.alt, newContext, config.semanticContext);
          // While we have context to pop back from, we may have
          // gotten that context AFTER having falling off a rule.
          // Make sure we track that we are now out of context.
          c.reachesIntoOuterContext = config.reachesIntoOuterContext;
          assert (depth > -pow(2, 53));
          _closureCheckingStopState(c, configs, closureBusy,
              collectPredicates, fullCtx, depth - 1, treatEofAsEpsilon);
        }
        return;
      } else if (fullCtx) {
        // reached end of start rule
        configs.add(config, _mergeCache);
        return;
      } else {
        // else if we have no context info, just chase follow links (if greedy)
      }
    }
    _closure_(config, configs, closureBusy,
        collectPredicates, fullCtx, depth, treatEofAsEpsilon);
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
    if (!p.onlyHasEpsilonTransitions) configs.add(config, _mergeCache);
    for (int i = 0; i < p.numberOfTransitions; i++) {
      Transition t = p.getTransition(i);
      bool continueCollecting = (t is! ActionTransition) && collectPredicates;
      AtnConfig c = _getEpsilonTarget(config, t,
          continueCollecting, depth == 0, fullCtx, treatEofAsEpsilon);
      if (c != null) {
        if (!t.isEpsilon && !closureBusy.add(c)) {
          // avoid infinite recursion for EOF* and EOF+
          // continue;
          continue;
        }
        int newDepth = depth;
        if (config.state is RuleStopState) {
          assert(!fullCtx);
          // target fell off end of rule; mark resulting c as having dipped
          // into outer context. We can't get here if incoming config was rule
          // stop and we had context track how far we dip into outer context.
          // Might come in handy and we avoid evaluating context dependent
          // preds if this is > 0.
          if (!closureBusy.add(c)) {
            // avoid infinite recursion for right-recursive rules
            continue;
          }
          c.reachesIntoOuterContext++;
          configs.dipsIntoOuterContext = true;
          assert(newDepth > -pow(2, 53));
          newDepth--;
        } else if (t is RuleTransition) {
          // latch when newDepth goes negative - once we step out of the
          // entry context we can't return
          if (newDepth >= 0) newDepth++;
        }
        _closureCheckingStopState(c, configs, closureBusy,
            continueCollecting, fullCtx, newDepth, treatEofAsEpsilon);
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
        return _precedenceTransition(
            config, t, collectPredicates, inContext, fullCtx);
      case Transition.PREDICATE:
        return _predTransition(
            config, t, collectPredicates, inContext, fullCtx);
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
    AtnConfig c = null;
    if (collectPredicates && inContext) {
      if (fullCtx) {
        // In full context mode, we can evaluate predicates on-the-fly
        // during closure, which dramatically reduces the size of
        // the config sets. It also obviates the need to test predicates
        // later during conflict resolution.
        int currentPosition = _input.index;
        _input.seek(_startIndex);
        bool predSucceeds = pt.predicate.eval(parser, _outerContext);
        _input.seek(currentPosition);
        if ( predSucceeds ) {
          c = new AtnConfig.from(config, state:pt.target); // no pred context
        }
      } else {
        var newCtx = SemanticContext.and(config.semanticContext, pt.predicate);
        c = new AtnConfig.from(config, state:pt.target, semanticContext:newCtx);
      }
    } else {
      c = new AtnConfig.from(config, state:pt.target);
    }
    return c;
  }

  AtnConfig _actionTransition(AtnConfig config, ActionTransition transition) {
    return new AtnConfig.from(config, state:transition.target);
  }

  AtnConfig _predTransition(AtnConfig config,
                            PredicateTransition pt,
                            bool collectPredicates,
                            bool inContext,
                            bool fullCtx) {
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
        bool predSucceeds = pt.predicate.eval(parser, _outerContext);
        _input.seek(currentPosition);
        if (predSucceeds) {
          c = new AtnConfig.from(config, state:pt.target); // no pred context
        }
      } else {
        var newCtx = SemanticContext.and(config.semanticContext, pt.predicate);
        c = new AtnConfig.from(config, state:pt.target, semanticContext:newCtx);
      }
    } else {
      c = new AtnConfig.from(config, state:pt.target);
    }
    return c;
  }

  AtnConfig _ruleTransition(AtnConfig config, RuleTransition t) {
    AtnState returnState = t.followState;
    var newContext = new SingletonPredictionContext
        .empty(config.context, returnState.stateNumber);
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
    return new NoViableAltException(
        parser,
        inputSource: input,
        startToken: input.get(startIndex),
        offendingToken:input.lookToken(1),
        context:outerContext,
        deadEndConfigs:configs);
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
  // DFA. If from is null, or if token is outside the
  // range of edges that can be represented in the DFA tables, this method
  // returns without adding the edge to the DFA.
  //
  // If to is null, this method returns null.
  // Otherwise, this method returns the DfaState returned by calling
  // _addDfaState_ for the to state.
  //
  // dfa is the DFA
  // from is the source state for the edge
  // token is the input symbol
  // to is the target state for the edge
  DfaState _addDfaEdge(Dfa dfa,
                       DfaState from,
                       int token,
                       DfaState to) {
    if (to == null) return null;
    to = _addDfaState_(dfa, to); // used existing if possible not incoming
    if (from == null || token < -1 || token > atn.maxTokenType) {
      return to;
    }
    if (from.edges == null) {
      from.edges = new List<DfaState>(atn.maxTokenType + 1 + 1);
    }
    from.edges[token+1] = to; // connect
    return to;
  }

  // Add state state to the DFA if it is not already present, and return
  // the actual instance stored in the DFA. If a state equivalent to state
  // is already in the DFA, the existing state is returned. Otherwise this
  // method returns state after adding it to the DFA.
  //
  // If state is ERROR, this method returns ERROR and
  // does not change the DFA.
  //
  // dfa is the dfa
  // state is the DFA state to add
  // Return the state stored in the DFA. This will be either the existing
  // state if state is already in the DFA, or state itself if the
  // state was not already present.
  DfaState _addDfaState_(Dfa dfa, DfaState state) {
    if (state == AtnSimulator.ERROR) return state;
    DfaState existing = dfa.states[state];
    if (existing != null) return existing;
    state.stateNumber = dfa.states.length;
    if (!state.configs.isReadonly) {
      state.configs.optimizeConfigs(this);
      state.configs.isReadonly = true;
    }
    dfa.states[state] = state;
    return state;
  }

  void _reportAttemptingFullContext(Dfa dfa,
                                    BitSet conflictingAlts,
                                    AtnConfigSet configs,
                                    int startIndex,
                                    int stopIndex) {
    if (parser != null)
      parser.errorListenerDispatch.reportAttemptingFullContext(
          parser, dfa, startIndex, stopIndex, conflictingAlts, configs);
  }

  void _reportContextSensitivity(Dfa dfa,
                                 int prediction,
                                 AtnConfigSet configs,
                                 int startIndex,
                                 int stopIndex) {
    if (parser != null)
      parser.errorListenerDispatch.reportContextSensitivity(
          parser, dfa, startIndex, stopIndex, prediction, configs);
  }

  // If context sensitive parsing, we know it's ambiguity not conflict.
  void _reportAmbiguity(Dfa dfa,
                        DfaState D,
                        int startIndex,
                        int stopIndex,
                        bool exact,
                        BitSet ambigAlts,
                        AtnConfigSet configs) {
    if (parser != null)
      parser.errorListenerDispatch.reportAmbiguity(
          parser, dfa, startIndex, stopIndex, exact, ambigAlts, configs);
  }
}

/// See [ParserInterpreter].
class LexerAtnSimulator extends AtnSimulator {

  static const int MIN_DFA_EDGE = 0;
  static const int MAX_DFA_EDGE = 127;

  final Lexer _recog;

  // The current token's starting index into the character source.
  // Shared across DFA to ATN simulation in case the ATN fails and the
  // DFA did not have a previous accept state. In this case, we use the
  // ATN-generated exception object.
  int _startIndex = -1;

  int _mode = Lexer.DEFAULT_MODE;

  // Used during DFA/ATN exec to record the most recent accept configuration info.
  final _SimState _prevAccept = new _SimState();

  /// Line number 1..n within the input.
  int line = 1;

  /// The index of the character relative to the beginning of the line 0..n-1.
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

  int match(StringSource input, int mode) {
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
    _mode = Lexer.DEFAULT_MODE;
  }

  Dfa getDfa(int mode) => decisionToDfa[mode];

  void clearDfa() {
    for (int d = 0; d < decisionToDfa.length; d++) {
      decisionToDfa[d] = new Dfa(atn.getDecisionState(d), d);
    }
  }

  /// Get the text matched so far for the current token.
  String getText(StringSource input) {
    // index is first lookahead char, don't include.
    return input.getText(Interval.of(_startIndex, input.index - 1));
  }

  void consume(StringSource input) {
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
    return (t == -1) ? "EOF" : "'${new String.fromCharCode(t)}'";
  }

  int _matchAtn(StringSource input) {
    AtnState startState = atn.modeToStartState[_mode];
    int old_mode = _mode;
    AtnConfigSet s0_closure = _computeStartState(input, startState);
    bool suppressEdge = s0_closure.hasSemanticContext;
    s0_closure.hasSemanticContext = false;
    DfaState next = _addDfaState(s0_closure);
    if (!suppressEdge) decisionToDfa[_mode].s0 = next;
    int predict = _execAtn(input, next);
    return predict;
  }

  int _execAtn(StringSource input, DfaState ds0) {
    int token = input.lookAhead(1);
    DfaState state = ds0; // s is current/from DFA state
    while (true) { // while more work
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
      DfaState target = _getExistingTargetState(state, token);
      if (target == null) {
        target = _computeTargetState(input, state, token);
      }
      if (target == AtnSimulator.ERROR) break;
      if (target.isAcceptState) {
        _captureSimState(_prevAccept, input, target);
        if (token == Token.EOF) break;
      }
      if (token != Token.EOF) {
        consume(input);
        token = input.lookAhead(1);
      }
      state = target; // flip; current DFA target becomes new src/from state
    }
    return _failOrAccept(_prevAccept, input, state.configs, token);
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
  DfaState _getExistingTargetState(DfaState state, int token) {
    if (state.edges == null
        || token < MIN_DFA_EDGE
        || token > MAX_DFA_EDGE) return null;
    DfaState target = state.edges[token - MIN_DFA_EDGE];
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
  DfaState _computeTargetState(StringSource input, DfaState s, int t) {
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
                    StringSource input,
                    AtnConfigSet reach,
                    int token) {
    if (prevAccept._dfaState != null) {
      var lexerActionExecutor = prevAccept._dfaState.lexerActionExecutor;
      _accept(input, lexerActionExecutor, _startIndex,
          prevAccept._index, prevAccept._line, prevAccept._charPos);
      return prevAccept._dfaState.prediction;
    } else {
      // if no accept and EOF is first char, return EOF
      if (token == Token.EOF && input.index == _startIndex) return Token.EOF;
      throw new LexerNoViableAltException(_recog, input, _startIndex, reach);
    }
  }

  // Given a starting configuration set, figure out all ATN configurations
  // we can reach upon input token. Parameter reach is a return
  // parameter.
  void _getReachableConfigSet(StringSource input,
                              AtnConfigSet closure,
                              AtnConfigSet reach,
                              int token) {
    // this is used to skip processing for configs which have a lower priority
    // than a config that already reached an accept state for the same rule
    int skipAlt = Atn.INVALID_ALT_NUMBER;
    for (AtnConfig c in closure) {
      bool currentAltReachedAcceptState = c.alt == skipAlt;
      if (currentAltReachedAcceptState
          && (c as LexerAtnConfig).hasPassedThroughNonGreedyDecision) {
        continue;
      }
      int n = c.state.numberOfTransitions;
      for (int ti = 0; ti < n; ti++) {
        Transition trans = c.state.getTransition(ti);
        AtnState target = _getReachableTarget(trans, token);
        if (target != null) {
          var executor = (c as LexerAtnConfig).lexerActionExecutor;
          if (executor != null) {
            executor = executor.fixOffsetBeforeMatch(input.index - _startIndex);
          }
          bool treatEofAsEpsilon = token == Token.EOF;
          if (_closure(input,
              new LexerAtnConfig.from(c, target, actionExecutor:executor),
              reach, currentAltReachedAcceptState, true, treatEofAsEpsilon)) {
            // any remaining configs for this alt have a lower priority than
            // the one that just reached an accept state.
            skipAlt = c.alt;
            break;
          }
        }
      }
    }
  }

  void _accept(StringSource input,
               LexerActionExecutor lexerActionExecutor,
               int startIndex,
               int index,
               int line,
               int charPos) {
    // seek to after last char in token
    input.seek(index);
    this.line = line;
    charPositionInLine = charPos;
    if (input.lookAhead(1) != Token.EOF) consume(input);
    if (lexerActionExecutor != null && _recog != null) {
      lexerActionExecutor.execute(_recog, input, startIndex);
    }
  }

  AtnState _getReachableTarget(Transition trans, int token) {
    if (trans.matches(token, Lexer.MIN_CHAR_VALUE, Lexer.MAX_CHAR_VALUE + 1)) {
      return trans.target;
    }
    return null;
  }

  AtnConfigSet _computeStartState(StringSource input, AtnState state) {
    PredictionContext initialContext = PredictionContext.EMPTY;
    AtnConfigSet configs = new AtnConfigSet();
    for (int i = 0; i< state.numberOfTransitions; i++) {
      AtnState target = state.getTransition(i).target;
      LexerAtnConfig c = new LexerAtnConfig(target, i + 1, initialContext);
      _closure(input, c, configs, false, false, false);
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
  bool _closure(StringSource input,
                LexerAtnConfig config,
                AtnConfigSet configs,
                bool currentAltReachedAcceptState,
                bool speculative,
                bool treatEofAsEpsilon) {
    if (config.state is RuleStopState) {
      if (config.context == null || config.context.hasEmptyPath) {
        if (config.context == null || config.context.isEmpty) {
          configs.add(config);
          return true;
        } else {
          configs.add(new LexerAtnConfig.from(
              config, config.state, context:PredictionContext.EMPTY));
          currentAltReachedAcceptState = true;
        }
      }
      if (config.context != null && !config.context.isEmpty) {
        for (int i = 0; i < config.context.length; i++) {
          if (config.context.returnStateFor(i)
              != PredictionContext.EMPTY_RETURN_STATE) {
            PredictionContext newContext = config.context.parentFor(i);
            AtnState returnState = atn.states[config.context.returnStateFor(i)];
            LexerAtnConfig c = new LexerAtnConfig.from(
                config, returnState, context:newContext);
            currentAltReachedAcceptState = _closure(input, c, configs,
                currentAltReachedAcceptState, speculative, treatEofAsEpsilon);
          }
        }
      }
      return currentAltReachedAcceptState;
    }
    // optimization
    if (!config.state.onlyHasEpsilonTransitions) {
      if (!currentAltReachedAcceptState
          || !config.hasPassedThroughNonGreedyDecision) {
        configs.add(config);
      }
    }
    AtnState p = config.state;
    for (int i = 0; i < p.numberOfTransitions; i++) {
      Transition t = p.getTransition(i);
      LexerAtnConfig c = _getEpsilonTarget(
          input, config, t, configs, speculative, treatEofAsEpsilon);
      if (c != null) {
        currentAltReachedAcceptState = _closure(input, c, configs,
            currentAltReachedAcceptState, speculative, treatEofAsEpsilon);
      }
    }
    return currentAltReachedAcceptState;
  }

  // side-effect: can alter configs.hasSemanticContext
  LexerAtnConfig _getEpsilonTarget(StringSource input,
                                   LexerAtnConfig config,
                                   Transition transition,
                                   AtnConfigSet configs,
                                   bool speculative,
                                   bool treatEofAsEpsilon) {
    LexerAtnConfig c = null;
    switch (transition.serializationType) {
      case Transition.RULE:
        var newContext = new SingletonPredictionContext.empty(config.context,
            (transition as RuleTransition).followState.stateNumber);
        c = new LexerAtnConfig.from(
            config, transition.target, context:newContext);
        break;
      case Transition.PRECEDENCE:
        throw new UnsupportedError(
            "Precedence predicates are not supported in lexers.");
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
        PredicateTransition pt = transition;
        configs.hasSemanticContext = true;
        if (_evaluatePredicate(
            input, pt.ruleIndex, pt.predIndex, speculative)) {
          c = new LexerAtnConfig.from(config, transition.target);
        }
        break;
      case Transition.ACTION:
        if (config.context == null || config.context.hasEmptyPath) {
          var executor = LexerActionExecutor.append(config.lexerActionExecutor,
              atn.lexerActions[(transition as ActionTransition).actionIndex]);
          c = new LexerAtnConfig.from(
              config, transition.target, actionExecutor:executor);
        } else {
          // ignore actions in referenced rules
          c = new LexerAtnConfig.from(config, transition.target);
        }
        break;
      case Transition.EPSILON:
        c = new LexerAtnConfig.from(config, transition.target);
        break;
      case Transition.ATOM:
      case Transition.RANGE:
      case Transition.SET:
        if (treatEofAsEpsilon) {
          if (transition.matches(
            Token.EOF, '\u0000'.codeUnitAt(0), '\uFFFF'.codeUnitAt(0))) {
            c = new LexerAtnConfig.from(config, transition.target);
            break;
          }
        }
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
  bool _evaluatePredicate(StringSource input,
                          int ruleIndex,
                          int predIndex,
                          bool speculative) {
    // assume true if no recognizer was provided
    if (_recog == null) return true;
    if (!speculative) return _recog.semanticPredicate(null, ruleIndex, predIndex);
    int savedCharPositionInLine = charPositionInLine;
    int savedLine = line;
    int index = input.index;
    int marker = input.mark;
    try {
      consume(input);
      return _recog.semanticPredicate(null, ruleIndex, predIndex);
    } finally {
      charPositionInLine = savedCharPositionInLine;
      line = savedLine;
      input.seek(index);
      input.release(marker);
    }
  }

  void _captureSimState(_SimState settings,
                        StringSource input,
                        DfaState dfaState) {
    settings
        .._index = input.index
        .._line = line
        .._charPos = charPositionInLine
        .._dfaState = dfaState;
  }

  DfaState _addDfaEdge(DfaState from,
                       int token,
                       AtnConfigSet set) {
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
    bool suppressEdge = set.hasSemanticContext;
    set.hasSemanticContext = false;
    DfaState to = _addDfaState(set);
    if (suppressEdge) return to;
    __addDfaEdge(from, token, to);
    return to;
  }

  void __addDfaEdge(DfaState pState, int token, DfaState qState) {
    // Only track edges within the DFA bounds
    if (token < MIN_DFA_EDGE || token > MAX_DFA_EDGE) return;
    Dfa dfa = decisionToDfa[_mode];
    if (pState.edges == null) {
      //  make room for tokens 1..n and -1 masquerading as index 0
      pState.edges = new List<DfaState>(MAX_DFA_EDGE-MIN_DFA_EDGE + 1);
    }
    pState.edges[token - MIN_DFA_EDGE] = qState; // connect
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
      proposed
          ..isAcceptState = true
          ..lexerActionExecutor = (
             firstConfigWithRuleStopState as LexerAtnConfig).lexerActionExecutor
          ..prediction = atn.ruleToTokenType[
             firstConfigWithRuleStopState.state.ruleIndex];
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

