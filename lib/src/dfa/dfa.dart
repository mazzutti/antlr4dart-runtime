part of antlr4dart;

class Dfa {
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

  Dfa(DecisionState this.atnStartState, [this.decision]);

  /**
   * Return a list of all states in this DFA, ordered by state number.
   */
  List<DfaState> get orderedStates {
    List<DfaState> result = new List<DfaState>.from(states.keys);
    result.sort((o1, o2) => o1.stateNumber - o2.stateNumber);
    return result;
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
