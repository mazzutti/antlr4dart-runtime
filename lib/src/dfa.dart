part of antlr4dart;

class Dfa {

  // true if this Dfa is for a precedence decision; otherwise,
  // false. This is the backing field for isPrecedenceDfa.
  bool _isPrecedenceDfa = false;

  /// A set of all DFA states. Use [Map] so we can get old state back
  /// ([Set] only allows you to see if it's there).
  final Map<DfaState, DfaState> states = new HashMap<DfaState, DfaState>();

  DfaState s0;

  final int decision;

  /// From which ATN state did we create this DFA?
  final DecisionState atnStartState;

  Dfa(this.atnStartState, [this.decision]);

  /// Return a list of all states in this DFA, ordered by state number.
  List<DfaState> get orderedStates {
    return new List<DfaState>.from(states.keys)
        ..sort((o1, o2) => o1.stateNumber - o2.stateNumber);
  }

  /// Gets whether this Dfa is a precedence Dfa.
  ///
  /// Precedence DFAs use a special start state [s0] which is not stored
  /// in [states]. The [DfaState.edges] list for this start state contains
  /// outgoing edges supplying individual start states corresponding to
  /// specific precedence values.
  ///
  /// Return `true` if this is a precedence DFA; otherwise, `false`.
  bool get isPrecedenceDfa => _isPrecedenceDfa;

  /// Sets whether this is a precedence Dfa.
  ///
  /// If the specified value differs from the current Dfa configuration, the
  /// following actions are taken. Otherwise no changes are made to the
  /// current DFA.
  ///
  /// [states] map is cleared.
  ///
  /// If [isPrecedenceDfa] is `false`, the initial state [s0] is set to `null`.
  /// Otherwise, it is initialized to a new [DfaState] with an empty outgoing
  /// [DfaState.edges] list to store the start states for individual precedence
  /// values.
  ///
  /// Param [isPrecedenceDfa] is `true` if this is a precedence Dfa. Otherwise,
  /// `false`.
  void set isPrecedenceDfa(bool isPrecedenceDfa) {
    if (_isPrecedenceDfa != isPrecedenceDfa) {
      states.clear();
      s0 = isPrecedenceDfa ?
          (new DfaState.config(new AtnConfigSet())
              ..edges = new List<DfaState>()
              ..isAcceptState = false
              ..requiresFullContext = false)
          : null;
      _isPrecedenceDfa = isPrecedenceDfa;
    }
  }

  /// Get the start state for a specific precedence value.
  ///
  /// [precedence] is the current precedence.
  ///
  /// Return the start state corresponding to the specified precedence, or
  /// `null` if no start state exists for the specified precedence.
  ///
  /// A [StateError] occurs when this is not a precedence Dfa.
  DfaState getPrecedenceStartStateFor(int precedence) {
    if (!isPrecedenceDfa) {
      throw new StateError(
          "Only precedence DFAs may contain a precedence start state.");
    }
    // s0.edges is never null for a precedence Dfa
    return (precedence < 0
        || precedence >= s0.edges.length) ? null : s0.edges[precedence];
  }

  /// Set the start state for a specific precedence value.
  ///
  /// [precedence] is the current precedence.
  /// [startState] is the start state corresponding to the specified
  /// precedence.
  ///
  /// A [StateError] occurs when his is not a precedence Dfa.
  void setPrecedenceStartStateFor(int precedence, DfaState startState) {
    if (!isPrecedenceDfa) {
      throw new StateError(
          "Only precedence DFAs may contain a precedence start state.");
    }
    if (precedence < 0) return;
    // When the DFA is turned into a precedence DFA, s0 will be initialized
    // once and not updated again s0.edges is never null for a precedence DFA.
    if (precedence >= s0.edges.length) {
      int n = precedence - s0.edges.length;
      for (int i = 0; i <= n; i++) s0.edges.add(null);
    }
    s0.edges[precedence] = startState;
  }

  String toString([List<String> tokenNames]) {
    return (s0 == null) ? "" : ((tokenNames != null)
        ? new DfaSerializer(this,tokenNames)
        : new LexerDfaSerializer(this)).toString();
  }
}

/// A DFA state represents a set of possible ATN configurations.
///
/// As Aho, Sethi, Ullman p. 117 says "The DFA uses its state
/// to keep track of all possible states the ATN can be in after
/// reading each input symbol.  That is to say, after reading
/// input a1a2..an, the DFA is in a state that represents the
/// subset T of the states of the ATN that are reachable from the
/// ATN's start state along some path labeled a1a2..an."
///
/// In conventional NFA->DFA conversion, therefore, the subset T
/// would be a [BitSet] representing the set of states the
/// ATN could be in.
///
/// We need to track the alt predicted by each state as well, however.
/// More importantly, we need to maintain a stack of states, tracking the
/// closure operations as they jump from rule to rule, emulating rule
/// invocations (method calls).
///
/// I have to add a stack to simulate the proper lookahead sequences for
/// the underlying LL grammar from which the ATN was derived.
///
/// I use a set of [AtnConfig] objects not simple states. An [AtnConfig]
/// is both a state (ala normal conversion) and a [RuleContext] describing
/// the chain of rules (if any) followed to arrive at that state.
///
/// A DFA state may have multiple references to a particular state,
/// but with different ATN contexts (with same or different alts)
/// meaning that state was reached via a different set of rule invocations.
class DfaState {

  int stateNumber = -1;

  AtnConfigSet configs = new AtnConfigSet();

  /// `edges[symbol]` points to target of symbol.
  ///
  /// Shift up by 1 so (-1) [Token.EOF] maps to `edges[0]`.
  List<DfaState> edges;

  bool isAcceptState = false;

  /// If accept state, what ttype do we match or alt do we predict?
  ///
  /// This is set to [Atn.INVALID_ALT_NUMBER] when `[predicates] != null`
  /// or [requiresFullContext].
  int prediction;

  LexerActionExecutor lexerActionExecutor;

  /// Indicates that this state was created during SLL prediction that
  /// discovered a conflict between the configurations in the state.
  ///
  /// Future [ParserAtnSimulator.execAtn] invocations immediately jumped doing
  /// full context prediction if this field is `true`.
  bool requiresFullContext = false;

  /// During SLL parsing, this is a list of predicates associated with the
  /// ATN configurations of the DFA state.
  ///
  /// When we have predicates, [requiresFullContext] is `false` since full
  /// context prediction evaluates predicates on-the-fly. If this is not `null`,
  /// then [prediction] is [Atn.INVALID_ALT_NUMBER].
  ///
  /// We only use these for non-[requiresFullContext] but conflicting states.
  /// That means we know from the context (it's $ or we don't dip into outer
  /// context) that it's an ambiguity not a conflict.
  ///
  /// This list is computed by the [ParserAtnSimulator].
  List<_PredPrediction> predicates;

  DfaState([this.stateNumber]);

  DfaState.config(this.configs);

  /// Get the set of all alts mentioned by all ATN configurations in this
  /// DFA state.
  Set<int> get altSet {
    Set<int> alts = new HashSet<int>();
    if (configs != null) {
      for (AtnConfig c in configs) alts.add(c.alt);
    }
    return (alts.isEmpty) ? null : alts;
  }

  int get hashCode {
    int hash = MurmurHash.initialize(7);
    hash = MurmurHash.update(hash, configs.hashCode);
    return MurmurHash.finish(hash, 1);
  }

  /// Two [DfaState] instances are equal if their ATN configuration sets
  /// are the same.
  ///
  /// This method is used to see if a state already exists.
  ///
  /// Because the number of alternatives and number of ATN configurations are
  /// finite, there is a finite number of DFA states that can be processed.
  /// This is necessary to show that the algorithm terminates.
  ///
  /// Cannot test the DFA state numbers here because in
  /// [ParserAtnSimulator.addDfaState] we need to know if any other state
  /// exists that has this exact set of ATN configurations. The [stateNumber]
  /// is irrelevant.
  bool operator==(Object other) {
    return  other is DfaState && configs == other.configs;
  }

  String toString() {
    StringBuffer sb = new StringBuffer()
        ..write(stateNumber)
        ..write(":")
        ..write(configs);
    if (isAcceptState) {
      sb
          ..write("=>")
          ..write(predicates != null ? predicates : prediction);
    }
    return sb.toString();
  }
}

/// Map a predicate to a predicted alternative.
class _PredPrediction {
  // never null; at least SemanticContext.NONE
  SemanticContext pred;
  int alt;
  _PredPrediction(this.pred, this.alt);
  String toString() => "($pred, $alt)";
}


/// A DFA walker that knows how to dump them to serialized strings.
class DfaSerializer {
  final Dfa dfa;
  final List<String> tokenNames;

  DfaSerializer(this.dfa, this.tokenNames);

  String toString() {
    if (dfa.s0 == null) return null;
    StringBuffer sb = new StringBuffer();
    List<DfaState> states = dfa.orderedStates;
    for (DfaState s in states) {
      int n = 0;
      if (s.edges != null) n = s.edges.length;
      int upperBound = pow(2, 53) - 1;
      for (int i = 0; i < n; i++) {
        DfaState t = s.edges[i];
        if (t != null && t.stateNumber < upperBound) {
          sb..write(_stateStringFor(s))
            ..write("-")
            ..write(_edgeLabelFor(i))
            ..write("->")
            ..writeln(_stateStringFor(t));
        }
      }
    }
    return sb.toString();
  }

  String _edgeLabelFor(int i) {
    return (i == 0)
        ? "EOF"
        : (tokenNames != null)
            ? tokenNames[i-1]
            : new String.fromCharCode(i);
  }

  String _stateStringFor(DfaState s) {
    StringBuffer sb = new StringBuffer(s.isAcceptState ? ':' : '')
        ..write('s')
        ..write(s.stateNumber)
        ..write(s.requiresFullContext ? '^' : '');
    if (s.isAcceptState) {
      sb
          ..write('=>')
          ..write(s.predicates != null ? s.predicates : s.prediction);
    }
    return sb.toString();
  }
}

class LexerDfaSerializer extends DfaSerializer {
  LexerDfaSerializer(Dfa dfa) : super(dfa, null);
  String _edgeLabelFor(int i) => "'${new String.fromCharCode(i)}'";
}
