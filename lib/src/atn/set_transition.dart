part of antlr4dart;

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


