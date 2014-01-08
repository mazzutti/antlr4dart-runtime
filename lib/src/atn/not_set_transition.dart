part of antlr4dart;

class NotSetTransition extends SetTransition {

  CharSource c;

  NotSetTransition(AtnState target, IntervalSet set) : super(target, set);

  int get serializationType => Transition.NOT_SET;

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) {
    return symbol >= minVocabSymbol
      && symbol <= maxVocabSymbol
      && !super.matches(symbol, minVocabSymbol, maxVocabSymbol);
  }

  String toString() => "~${super.toString()}";
}
