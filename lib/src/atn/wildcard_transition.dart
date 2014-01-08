part of antlr4dart;

class WildcardTransition extends Transition {
  WildcardTransition(AtnState target) : super._internal(target);

  int get serializationType => Transition.WILDCARD;

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) {
    return symbol >= minVocabSymbol && symbol <= maxVocabSymbol;
  }

  String toString() => ".";
}
