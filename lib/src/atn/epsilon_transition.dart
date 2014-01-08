part of antlr4dart;

class EpsilonTransition extends Transition {

  EpsilonTransition(AtnState target) : super._internal(target);

  int get serializationType => Transition.EPSILON;

  bool get isEpsilon => true;

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) {
    return false;
  }

  String toString() => "epsilon";
}
