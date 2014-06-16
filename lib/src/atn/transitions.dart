part of antlr4dart;

///  An ATN transition between any two ATN states. Subclasses define atom, set,
///  epsilon, action, predicate, rule transitions.
///
///  This is a one way link. It emanates from a state (usually via a list of
///  transitions) and has a target state.
///
///  Since we never have to change the ATN transitions once we construct it,
///  we can fix these transitions as specific classes. The DFA transitions
///  on the other hand need to update the labels as it adds transitions to
///  the states. We'll use the term Edge for the DFA to distinguish them from
///  ATN transitions.
abstract class Transition {

  static const int EPSILON = 1;
  static const int RANGE = 2;
  static const int RULE = 3;
  static const int PREDICATE = 4;
  static const int ATOM = 5;
  static const int ACTION = 6;
  static const int SET = 7;
  static const int NOT_SET = 8;
  static const int WILDCARD = 9;
  static const int PRECEDENCE = 10;

  static const List<String> serializationNames =
    const <String>["INVALID", "EPSILON", "RANGE", "RULE", "PREDICATE", "ATOM",
      "ACTION", "SET", "NOT_SET", "WILDCARD", "PRECEDENCE"
    ];

  /// The target of this transition.
  AtnState target;

  Transition._internal(this.target) {
    if (target == null) {
      throw new ArgumentError(target);
    }
  }

  int get serializationType;

  /// Are we epsilon, action or sempred?
  bool get isEpsilon => false;

  IntervalSet get label => null;

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol);
}

class RangeTransition extends Transition {
  final int from;
  final int to;

  RangeTransition(AtnState target, this.from, this.to)
      : super._internal(target);

  int get serializationType => Transition.RANGE;

  IntervalSet get label => IntervalSet.of(from, to);

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) {
    return symbol >= from && symbol <= to;
  }

  String toString()
    => "'${new String.fromCharCode(from)}'..'${new String.fromCharCode(to)}'";
}

/// A transition containing a set of values.
class SetTransition extends Transition {
  final IntervalSet set;

  SetTransition(AtnState target, [IntervalSet set])
    : this.set = (set != null) ? set : IntervalSet.ofSingle(Token.INVALID_TYPE),
      super._internal(target);

  int get serializationType => Transition.SET;

  IntervalSet get label => set;

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) {
    return set.contains(symbol);
  }

  String toString() => set.toString();
}

class WildcardTransition extends Transition {
  WildcardTransition(AtnState target) : super._internal(target);

  int get serializationType => Transition.WILDCARD;

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) {
    return symbol >= minVocabSymbol && symbol <= maxVocabSymbol;
  }

  String toString() => ".";
}

class RuleTransition extends Transition {

  final int precedence;

  /// Ptr to the rule definition object for this rule ref.
  final int ruleIndex;

  /// What node to begin computations following ref to rule.
  AtnState followState;

  RuleTransition(RuleStartState ruleStart,
                 this.ruleIndex,
                 this.precedence,
                 this.followState) : super._internal(ruleStart);

  int get serializationType => Transition.RULE;

  bool get isEpsilon => true;

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) => false;
}

///  A tree of semantic predicates from the grammar AST if `label == `SEMPRED`.
///  In the ATN, labels will always be exactly one predicate, but the DFA
///  may have to combine a bunch of them as it collects predicates from
///  multiple ATN configurations into a single DFA state.
class PredicateTransition extends AbstractPredicateTransition {

  final int ruleIndex;
  final int predIndex;
  final bool isCtxDependent;

  PredicateTransition(AtnState target,
                      this.ruleIndex,
                      this.predIndex,
                      this.isCtxDependent) : super(target);

  int get serializationType => Transition.PREDICATE;

  bool get isEpsilon => true;

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) => false;

  Predicate get predicate {
    return new Predicate(ruleIndex, predIndex, isCtxDependent);
  }

  String toString() => "pred_$ruleIndex:$predIndex";
}

class NotSetTransition extends SetTransition {

  StringSource stringSource;

  NotSetTransition(AtnState target, IntervalSet set) : super(target, set);

  int get serializationType => Transition.NOT_SET;

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) {
    return symbol >= minVocabSymbol
      && symbol <= maxVocabSymbol
      && !super.matches(symbol, minVocabSymbol, maxVocabSymbol);
  }

  String toString() => "~${super.toString()}";
}

abstract class AbstractPredicateTransition extends Transition {

  AbstractPredicateTransition(AtnState target) : super._internal(target);

}

class PrecedencePredicateTransition extends AbstractPredicateTransition {
  final int precedence;

  PrecedencePredicateTransition(AtnState target, this.precedence)
      : super(target);

  int get serializationType => Transition.PRECEDENCE;

  bool get isEpsilon => true;

  PrecedencePredicate get predicate => new PrecedencePredicate(precedence);

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) => false;

  String toString() => "$precedence  >= _p";
}

class ActionTransition extends Transition {
  final int ruleIndex;
  final int actionIndex;
  final bool isCtxDependent;

  ActionTransition(AtnState target,
                   this.ruleIndex,
                   [this.actionIndex = -1,
                   this.isCtxDependent = false]) : super._internal(target);

  int get serializationType => Transition.ACTION;

  bool get isEpsilon => true;

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) => false;

  String toString() => "action_$ruleIndex:$actionIndex";
}

class AtomTransition extends Transition {
  /// The token type or character value; or, signifies special label.
  final int especialLabel;

  AtomTransition(AtnState target, this.especialLabel) : super._internal(target);

  int get serializationType => Transition.ATOM;

  IntervalSet get label => IntervalSet.ofSingle(especialLabel);

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) {
    return especialLabel == symbol;
  }

  String toString() => "$especialLabel";
}

class EpsilonTransition extends Transition {

  EpsilonTransition(AtnState target) : super._internal(target);

  int get serializationType => Transition.EPSILON;

  bool get isEpsilon => true;

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) => false;

  String toString() => "epsilon";
}
