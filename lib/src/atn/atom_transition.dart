part of antlr4dart;

class AtomTransition extends Transition {
  /**
   * The token type or character value; or, signifies special label.
   */
  final int especialLabel;

  AtomTransition(AtnState target, this.especialLabel) : super._internal(target);

  int get serializationType => Transition.ATOM;

  IntervalSet get label => IntervalSet.ofSingle(especialLabel);

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) {
    return especialLabel == symbol;
  }

  String toString() => "$especialLabel";
}
