part of antlr4dart;

abstract class AtnState {

  // constants for serialization
  static const int INVALID_TYPE = 0;
  static const int BASIC = 1;
  static const int RULE_START = 2;
  static const int BLOCK_START = 3;
  static const int PLUS_BLOCK_START = 4;
  static const int STAR_BLOCK_START = 5;
  static const int TOKEN_START = 6;
  static const int RULE_STOP = 7;
  static const int BLOCK_END = 8;
  static const int STAR_LOOP_BACK = 9;
  static const int STAR_LOOP_ENTRY = 10;
  static const int PLUS_LOOP_BACK = 11;
  static const int LOOP_END = 12;

  static const List<String> serializationNames =
    const <String>[
      "INVALID",
      "BASIC",
      "RULE_START",
      "BLOCK_START",
      "PLUS_BLOCK_START",
      "STAR_BLOCK_START",
      "TOKEN_START",
      "RULE_STOP",
      "BLOCK_END",
      "STAR_LOOP_BACK",
      "STAR_LOOP_ENTRY",
      "PLUS_LOOP_BACK",
      "LOOP_END"
    ];

  static const int INVALID_STATE_NUMBER = -1;

  /// Which ATN are we in?
  Atn atn = null;

  int stateNumber = INVALID_STATE_NUMBER;

  int ruleIndex; // at runtime, we don't have Rule objects

  bool epsilonOnlyTransitions = false;

  /// Track the transitions emanating from this ATN state.
  final List<Transition> _transitions = new List<Transition>();

  /// Used to cache lookahead during parsing, not used during construction
  IntervalSet nextTokenWithinRule;

  int get hashCode => stateNumber;

  bool operator==(Object o) {
    // are these states same object?
    if (o is AtnState) return stateNumber == o.stateNumber;
    return false;
  }

  bool get isNonGreedyExitState => false;

  String toString() => "$stateNumber";

  List<Transition> get transitions => new List<Transition>.from(_transitions);

  int get numberOfTransitions => _transitions.length;

  void addTransition(Transition e) {
    addTransitionAt(e);
  }

  void addTransitionAt(Transition e, [int index]) {
    if (_transitions.isEmpty) {
      epsilonOnlyTransitions = e.isEpsilon;
    } else if (epsilonOnlyTransitions != e.isEpsilon) {
      print("ATN state $stateNumber has both epsilon and non-epsilon transitions.");
      epsilonOnlyTransitions = false;
    }
    if (index != null) {
      _transitions.insert(index, e);
    } else {
      _transitions.add(e);
    }
  }

  Transition transition(int i) => _transitions[i];

  void setTransition(int i, Transition e) {
    transitions[i] = e;
  }

  Transition removeTransition(int index) => _transitions.removeAt(index);

  int get stateType;

  bool get onlyHasEpsilonTransitions => epsilonOnlyTransitions;
}
