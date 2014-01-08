part of antlr4dart;

class EmptyPredictionContext extends SingletonPredictionContext {
  EmptyPredictionContext() : super(null, PredictionContext.EMPTY_RETURN_STATE);

  bool get isEmpty => true;

  int get length => 1;

  PredictionContext getParent(int index) => null;

  int getReturnState(int index) => returnState;

  String toString() => r"$";
}
