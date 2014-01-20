part of antlr4dart;

/**
 * A DFA state represents a set of possible ATN configurations.
 * As Aho, Sethi, Ullman p. 117 says "The DFA uses its state
 * to keep track of all possible states the ATN can be in after
 * reading each input symbol.  That is to say, after reading
 * input a1a2..an, the DFA is in a state that represents the
 * subset T of the states of the ATN that are reachable from the
 * ATN's start state along some path labeled a1a2..an."
 * In conventional NFA->DFA conversion, therefore, the subset T
 * would be a bitset representing the set of states the
 * ATN could be in.  We need to track the alt predicted by each
 * state as well, however.  More importantly, we need to maintain
 * a stack of states, tracking the closure operations as they
 * jump from rule to rule, emulating rule invocations (method calls).
 * I have to add a stack to simulate the proper lookahead sequences for
 * the underlying LL grammar from which the ATN was derived.
 *
 * I use a set of AtnConfig objects not simple states.  An AtnConfig
 * is both a state (ala normal conversion) and a RuleContext describing
 * the chain of rules (if any) followed to arrive at that state.
 *
 * A DFA state may have multiple references to a particular state,
 * but with different ATN contexts (with same or different alts)
 * meaning that state was reached via a different set of rule invocations.
 */
class DfaState {

  int stateNumber = -1;

  AtnConfigSet configs = new AtnConfigSet();

  /**
   * `edges[symbol]` points to target of symbol. Shift up by 1 so (-1)
   *  [Token.EOF] maps to `edges[0]`.
   */
  List<DfaState> edges;

  bool isAcceptState = false;

  /**
   * If accept state, what ttype do we match or alt do we predict?
   * This is set to [Atn.INVALID_ALT_NUMBER] when `[predicates] != null`
   * or [requiresFullContext].
   */
  int prediction;

  LexerActionExecutor lexerActionExecutor;

  /**
   * Indicates that this state was created during SLL prediction that
   * discovered a conflict between the configurations in the state. Future
   * [ParserAtnSimulator.execAtn] invocations immediately jumped doing
   * full context prediction if this field is true.
   */
  bool requiresFullContext = false;

  /**
   * During SLL parsing, this is a list of predicates associated with the
   * ATN configurations of the DFA state. When we have predicates,
   * [requiresFullContext] is `false` since full context prediction
   * evaluates predicates on-the-fly. If this is not null, then [prediction]
   * is [Atn.INVALID_ALT_NUMBER].
   *
   * We only use these for non-[requiresFullContext] but conflicting states.
   * That means we know from the context (it's $ or we don't dip into outer
   * context) that it's an ambiguity not a conflict.
   *
   * This list is computed by [ParserAtnSimulator.predicateDFAState].
   */
  List<PredPrediction> predicates;

  DfaState([this.stateNumber]);

  DfaState.config(this.configs);

  /**
   * Get the set of all alts mentioned by all ATN configurations in this
   * DFA state.
   */
  Set<int> get altSet {
    Set<int> alts = new HashSet<int>();
    if (configs != null) {
      for (AtnConfig c in configs) {
        alts.add(c.alt);
      }
    }
    if (alts.isEmpty) return null;
    return alts;
  }

  int get hashCode {
    int hash = MurmurHash.initialize(7);
    hash = MurmurHash.update(hash, configs.hashCode);
    hash = MurmurHash.finish(hash, 1);
    return hash;
  }

  /**
   * Two [DfaState] instances are equal if their ATN configuration sets
   * are the same. This method is used to see if a state already exists.
   *
   * Because the number of alternatives and number of ATN configurations are
   * finite, there is a finite number of DFA states that can be processed.
   * This is necessary to show that the algorithm terminates.
   *
   * Cannot test the DFA state numbers here because in
   * [ParserAtnSimulator.addDfaState] we need to know if any other state
   * exists that has this exact set of ATN configurations. The
   * [stateNumber] is irrelevant.
   */
  bool operator==(Object o) {
    // compare set of ATN configurations in this set with other
    if (o is DfaState) {
      bool sameSet = configs == o.configs;
      return sameSet;
    }
    return false;
  }

  String toString() {
    StringBuffer buf = new StringBuffer();
    buf..write(stateNumber)..write(":")..write(configs);
    if (isAcceptState) {
      buf.write("=>");
      if (predicates != null) {
        buf.write(predicates);
      } else {
        buf.write(prediction);
      }
    }
    return buf.toString();
  }
}

/**
 * Map a predicate to a predicted alternative.
 */
class PredPrediction {
  // never null; at least SemanticContext.NONE
  SemanticContext pred;
  int alt;
  PredPrediction(this.pred, this.alt);
  String toString() => "($pred, $alt)";
}
