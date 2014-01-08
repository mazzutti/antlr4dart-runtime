part of antlr4dart;

class RangeTransition extends Transition {
  final int from;
  final int to;

  RangeTransition(AtnState target, this.from, this.to) : super._internal(target);

  int get serializationType => Transition.RANGE;

  IntervalSet get label => IntervalSet.of(from, to);

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) {
    return symbol >= from && symbol <= to;
  }

  String toString() => "'${new String.fromCharCode(from)}'..'${new String.fromCharCode(to)}'";
}
