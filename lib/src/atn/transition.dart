part of antlr4dart;

/**
 *  An ATN transition between any two ATN states.  Subclasses define
 *  atom, set, epsilon, action, predicate, rule transitions.
 *
 *  This is a one way link. It emanates from a state (usually via a list of
 *  transitions) and has a target state.
 *
 *  Since we never have to change the ATN transitions once we construct it,
 *  we can fix these transitions as specific classes. The DFA transitions
 *  on the other hand need to update the labels as it adds transitions to
 *  the states. We'll use the term Edge for the DFA to distinguish them from
 *  ATN transitions.
 */
abstract class Transition {
  // constants for serialization
  static const int EPSILON = 1;
  static const int RANGE = 2;
  static const int RULE = 3;
  static const int PREDICATE = 4; // e.g., {isType(input.lookToken(1))}?
  static const int ATOM = 5;
  static const int ACTION = 6;
  static const int SET = 7; // ~(A|B) or ~atom, wildcard, which convert to next 2
  static const int NOT_SET = 8;
  static const int WILDCARD = 9;
  static const int PRECEDENCE = 10;


  static const List<String> serializationNames =
    const <String>[
      "INVALID",
      "EPSILON",
      "RANGE",
      "RULE",
      "PREDICATE",
      "ATOM",
      "ACTION",
      "SET",
      "NOT_SET",
      "WILDCARD",
      "PRECEDENCE"
    ];

  static const Map<Type, int> serializationTypes =
    const <Type, int>{
      EpsilonTransition: EPSILON,
      RangeTransition: RANGE,
      RuleTransition: RULE,
      PredicateTransition: PREDICATE,
      AtomTransition: ATOM,
      ActionTransition: ACTION,
      SetTransition: SET,
      NotSetTransition: NOT_SET,
      WildcardTransition: WILDCARD,
      PrecedencePredicateTransition: PRECEDENCE
    };

  /**
   * The target of this transition.
   */
  AtnState target;

  Transition._internal(this.target) {
    if (target == null) {
      throw new ArgumentError(target);
    }
  }

  int get serializationType;

  /**
   * Are we epsilon, action, sempred?
   */
  bool get isEpsilon => false;

  IntervalSet get label => null;

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol);
}
