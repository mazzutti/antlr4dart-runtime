part of antlr4dart;

class SingletonPredictionContext extends PredictionContext {
  final PredictionContext parent;
  final int returnState;

  SingletonPredictionContext(PredictionContext parent, int returnState)
    : super._internal(
        (parent != null)
          ? PredictionContext._calculateHashCode(parent, returnState)
              : PredictionContext._calculateEmptyHashCode()),
    this.parent = parent, this.returnState = returnState {
    assert(returnState != AtnState.INVALID_STATE_NUMBER);
  }

  static SingletonPredictionContext create(PredictionContext parent, int returnState) {
    if (returnState == PredictionContext.EMPTY_RETURN_STATE && parent == null) {
      // someone can pass in the bits of an array ctx that mean $
      return PredictionContext.EMPTY;
    }
    return new SingletonPredictionContext(parent, returnState);
  }

  int get length => 1;

  PredictionContext getParent(int index) {
    assert(index == 0);
    return parent;
  }

  int getReturnState(int index) {
    assert(index == 0);
    return returnState;
  }

  bool operator ==(Object o) {
    if (o is SingletonPredictionContext) {
      // can't be same if hash is different
      if (hashCode != o.hashCode) return false;
      return returnState == o.returnState && parent == o.parent;
    }
    return false;
  }

  String toString() {
    String up = parent != null ? parent.toString() : "";
    if (up.length == 0) {
      if (returnState == PredictionContext.EMPTY_RETURN_STATE) {
        return r"$";
      }
      return "$returnState";
    }
    return "$returnState $up";
  }
}
