part of antlr4dart;

class PrecedencePredicateTransition extends AbstractPredicateTransition {
  final int precedence;

  PrecedencePredicateTransition(AtnState target, this.precedence) : super(target);

  int get serializationType => Transition.PRECEDENCE;

  bool get isEpsilon => true;

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) {
    return false;
  }

  PrecedencePredicate get predicate {
    return new PrecedencePredicate(precedence);
  }

  String toString() => "$precedence  >= _p";
}
