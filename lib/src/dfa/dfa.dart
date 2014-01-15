part of antlr4dart;

class Dfa {

  // true if this Dfa is for a precedence decision; otherwise,
  // false. This is the backing field for isPrecedenceDfa.
  bool _precedenceDfa = false;

  /**
   * A set of all DFA states. Use [Map] so we can get old state back
   * ([Set] only allows you to see if it's there).
   */
  final Map<DfaState, DfaState> states = new HashMap<DfaState, DfaState>();

  DfaState s0;

  final int decision;

  /**
   * From which ATN state did we create this DFA?
   */
  final DecisionState atnStartState;

  Dfa(this.atnStartState, [this.decision]);

  /**
   * Return a list of all states in this DFA, ordered by state number.
   */
  List<DfaState> get orderedStates {
    List<DfaState> result = new List<DfaState>.from(states.keys);
    result.sort((o1, o2) => o1.stateNumber - o2.stateNumber);
    return result;
  }

  /**
   * Gets whether this Dfa is a precedence Dfa. Precedence DFAs use a special
   * start state [s0] which is not stored in [states]. The
   * [DfaState.edges] array for this start state contains outgoing edges
   * supplying individual start states corresponding to specific precedence
   * values.
   *
   * Return `true` if this is a precedence DFA; otherwise, `false`.
   */
  bool get isPrecedenceDfa => _precedenceDfa;

  /**
   * Sets whether this is a precedence Dfa. If the specified value differs
   * from the current Dfa configuration, the following actions are taken;
   * otherwise no changes are made to the current DFA.
   *
   * [states] map is cleared.
   * If [precedenceDfa} is `false`, the initial state [s0] is set to `null`;
   * otherwise, it is initialized to a new [DfaState] with an empty outgoing
   * [DfaState.edges] list to store the start states for individual precedence
   * values.
   *
   * Param [precedenceDfa] is `true` if this is a precedence Dfa; otherwise,
   * `false`.
   */
  void set isPrecedenceDfa(bool precedenceDfa) {
    if (_precedenceDfa != precedenceDfa) {
      states.clear();
      if (precedenceDfa) {
        DfaState precedenceState = new DfaState.config(new AtnConfigSet());
        precedenceState.edges = new List<DfaState>();
        precedenceState.isAcceptState = false;
        precedenceState.requiresFullContext = false;
        s0 = precedenceState;
      } else {
        s0 = null;
      }
      _precedenceDfa = precedenceDfa;
    }
  }

  /**
   * Get the start state for a specific precedence value.
   *
   * [precedence] is the current precedence.
   * Return the start state corresponding to the specified precedence, or
   * `null` if no start state exists for the specified precedence.
   *
   * Throws [StateError] if this is not a precedence Dfa.
   */
  DfaState getPrecedenceStartState(int precedence) {
    if (!isPrecedenceDfa) {
      throw new StateError("Only precedence DFAs may contain a precedence start state.");
    }
    // s0.edges is never null for a precedence Dfa
    if (precedence < 0 || precedence >= s0.edges.length) {
      return null;
    }
    return s0.edges[precedence];
  }

  /**
   * Set the start state for a specific precedence value.
   *
   * [precedence] is the current precedence.
   * [startState] is the start state corresponding to the specified
   * precedence.
   *
   * Throws [StateError] if this is not a precedence Dfa.
   */
  void setPrecedenceStartState(int precedence, DfaState startState) {
    if (!isPrecedenceDfa) {
      throw new StateError("Only precedence DFAs may contain a precedence start state.");
    }
    if (precedence < 0) return;
    // synchronization on s0 here is ok. when the DFA is turned into a
    // precedence DFA, s0 will be initialized once and not updated again
    // s0.edges is never null for a precedence DFA
    if (precedence >= s0.edges.length) {
      int n = precedence - s0.edges.length;
      for (int i = 0; i <= n; i++) s0.edges.add(null);
    }
    s0.edges[precedence] = startState;
  }

  String toString([List<String> tokenNames]) {
    if (s0 == null) return "";
    DfaSerializer serializer = new DfaSerializer(this,tokenNames);
    return serializer.toString();
  }

  String toLexerString() {
    if (s0 == null) return "";
    DfaSerializer serializer = new LexerDfaSerializer(this);
    return serializer.toString();
  }
}
