part of antlr4dart;

class ListPredictionContext extends PredictionContext {
  /**
   * Parent can be null only if full ctx mode and we make a list
   * from [PredictionContext.EMPTY] and non-empty. We merge
   * [PredictionContext.EMPTY] by using null parent and
   * `returnState == PredictionContext.EMPTY_RETURN_STATE`.
   */
  final List<PredictionContext> parents;

  /** Sorted for merge, no duplicates; if present,
   *  [PredictionContext.EMPTY_RETURN_STATE] is always last.
   */
  final List<int> returnStates;

  ListPredictionContext(List<PredictionContext> parents, List<int> returnStates)
      : super._internal(PredictionContext._calculateHashCodes(parents, returnStates)),
      this.parents = parents,
      this.returnStates = returnStates {
    assert(parents != null && parents.length > 0);
    assert(returnStates != null && returnStates.length > 0);
  }

  ListPredictionContext.from(SingletonPredictionContext a)
    : this([a.parent], [a.returnState]);

  bool get isEmpty {
    // since EMPTY_RETURN_STATE can only appear in the last position, we
    // don't need to verify that size == 1
    return returnStates[0] == PredictionContext.EMPTY_RETURN_STATE;
  }

  int get length => returnStates.length;

  PredictionContext getParent(int index) => parents[index];

  int getReturnState(int index) => returnStates[index];

  bool operator==(Object o) {
    if (o is ListPredictionContext) {
      // can't be same if hash is different
      if (hashCode != o.hashCode) return false;
      return returnStates == o.returnStates && parents == o.parents;
    }
    return false;
  }

  String toString() {
    if (isEmpty) return "[]";
    StringBuffer buf = new StringBuffer("[");
    for (int i = 0; i < returnStates.length; i++) {
      if (i > 0) buf.write(", ");
      if (returnStates[i] == PredictionContext.EMPTY_RETURN_STATE) {
        buf.write(r"$");
        continue;
      }
      buf.write(returnStates[i]);
      if (parents[i] != null) {
        buf.write(' ');
        buf.write(parents[i]);
      } else {
        buf.write("null");
      }
    }
    buf.write("]");
    return buf.toString();
  }
}
