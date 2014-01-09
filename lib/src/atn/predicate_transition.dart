part of antlr4dart;

/**
 *  A tree of semantic predicates from the grammar AST if `label == `SEMPRED`.
 *  In the ATN, labels will always be exactly one predicate, but the DFA
 *  may have to combine a bunch of them as it collects predicates from
 *  multiple ATN configurations into a single DFA state.
 */
class PredicateTransition extends AbstractPredicateTransition {

  final int ruleIndex;
  final int predIndex;
  final bool isCtxDependent;  // e.g., $i ref in pred

  PredicateTransition(AtnState target,
                      this.ruleIndex,
                      this.predIndex,
                      this.isCtxDependent) : super(target);

  int get serializationType => Transition.PREDICATE;

  bool get isEpsilon => true;

  bool matches(int symbol, int minVocabSymbol, int maxVocabSymbol) {
    return false;
  }

  Predicate get predicate {
    return new Predicate(ruleIndex, predIndex, isCtxDependent);
  }

  String toString() => "pred_$ruleIndex:$predIndex";
}
