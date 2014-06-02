part of antlr4dart;

abstract class AtnState {

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
    const <String>[ "INVALID", "BASIC", "RULE_START", "BLOCK_START",
      "PLUS_BLOCK_START", "STAR_BLOCK_START", "TOKEN_START", "RULE_STOP",
      "BLOCK_END", "STAR_LOOP_BACK", "STAR_LOOP_ENTRY", "PLUS_LOOP_BACK",
      "LOOP_END"
    ];

  static const int INVALID_STATE_NUMBER = -1;

  /// Which ATN are we in?
  Atn atn = null;

  int stateNumber = INVALID_STATE_NUMBER;

  int ruleIndex;

  bool epsilonOnlyTransitions = false;

  /// Track the transitions emanating from this ATN state.
  final List<Transition> _transitions = new List<Transition>();

  /// Used to cache lookahead during parsing, not used during construction.
  IntervalSet nextTokenWithinRule;

  int get hashCode => stateNumber;

  int get stateType;

  bool get isNonGreedyExitState => false;

  List<Transition> get transitions => new List<Transition>.from(_transitions);

  int get numberOfTransitions => _transitions.length;

  bool get onlyHasEpsilonTransitions => epsilonOnlyTransitions;

  bool operator==(Object other) {
    return other is AtnState && stateNumber == other.stateNumber;
  }

  String toString() => "$stateNumber";

  void addTransition(Transition e) {
    addTransitionAt(e);
  }

  void addTransitionAt(Transition e, [int index]) {
    if (_transitions.isEmpty) {
      epsilonOnlyTransitions = e.isEpsilon;
    } else if (epsilonOnlyTransitions != e.isEpsilon) {
      epsilonOnlyTransitions = false;
    }
    if (index != null) {
      _transitions.insert(index, e);
    } else {
      _transitions.add(e);
    }
  }

  Transition getTransition(int i) => _transitions[i];

  void setTransition(int i, Transition e) {
    transitions[i] = e;
  }

  Transition removeTransition(int index) => _transitions.removeAt(index);
}

class BasicState extends AtnState {
  int get stateType => AtnState.BASIC;
}

class BasicBlockStartState extends BlockStartState {
  int get stateType => AtnState.BLOCK_START;
}

/// Terminal node of a simple `(a|b|c)` block.
class BlockEndState extends AtnState {
  BlockStartState startState;
  int get stateType => AtnState.BLOCK_END;
}

/// The start of a regular `(...)` block.
abstract class BlockStartState extends DecisionState {
  BlockEndState endState;
}

abstract class DecisionState extends AtnState {
  int decision = -1;
  bool nonGreedy = false;
}

/// Mark the end of a * or + loop.
class LoopEndState extends AtnState {
  AtnState loopBackState;
  int get stateType => AtnState.LOOP_END;
}

/// Start of `(A|B|...)+` loop. Technically a decision state, but we don't
/// use for code generation; somebody might need it, so I'm defining it for
/// completeness. In reality, the [PlusLoopbackState] node is the real
/// decision-making note for `A+`.
class PlusBlockStartState extends BlockStartState {
  PlusLoopbackState loopBackState;
  int get stateType => AtnState.PLUS_BLOCK_START;
}

/// Decision state for `A+` and `(A|B)+`. It has two transitions:
/// one to the loop back to start of the block and one to exit.
class PlusLoopbackState extends DecisionState {
  int get stateType => AtnState.PLUS_LOOP_BACK;
}

class RuleStartState extends AtnState {
  RuleStopState stopState;
  bool isPrecedenceRule = false;
  int get stateType => AtnState.RULE_START;
}

/// The last node in the ATN for a rule, unless that rule is the start symbol.
/// In that case, there is one transition to `EOF`. Later, we might encode
/// references to all calls to this rule to compute `FOLLOW` sets for
/// error handling.
class RuleStopState extends AtnState {
  int get stateType => AtnState.RULE_STOP;
}

/// The block that begins a closure loop.
class StarBlockStartState extends BlockStartState {
  int get stateType => AtnState.STAR_BLOCK_START;
}

class StarLoopbackState extends AtnState {
  int get stateType => AtnState.STAR_LOOP_BACK;
  StarLoopEntryState get loopEntryState => getTransition(0).target;
}

class StarLoopEntryState extends DecisionState {
  StarLoopbackState loopBackState;

  /// Indicates whether this state can benefit from a precedence Dfa
  /// during SLL decision making.
  ///
  /// This is a computed property that is calculated during ATN
  /// deserialization and stored for use in [ParserAtnSimulator] and
  /// [ParserInterpreter].
  bool precedenceRuleDecision = false;

  int get stateType => AtnState.STAR_LOOP_ENTRY;
}

/// The Tokens rule start state linking to each lexer rule start state.
class TokensStartState extends DecisionState {
  int get stateType => AtnState.TOKEN_START;
}
