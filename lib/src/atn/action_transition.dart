part of antlr4dart;

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

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) {
    return false;
  }

  String toString() => "action_$ruleIndex:$actionIndex";
}
