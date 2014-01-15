part of antlr4dart;

class RuleTransition extends Transition {
  /**
   * Ptr to the rule definition object for this rule ref
   */
  final int ruleIndex; // no Rule object at runtime
  
  final int precedence;

  /**
   * What node to begin computations following ref to rule
   */
  AtnState followState;

  RuleTransition(RuleStartState ruleStart,
                 this.ruleIndex,
                 this.precedence,
                 this.followState) : super._internal(ruleStart);

  int get serializationType => Transition.RULE;

  bool get isEpsilon => true;

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) {
    return false;
  }
}
