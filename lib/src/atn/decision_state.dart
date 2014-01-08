part of antlr4dart;

abstract class DecisionState extends AtnState {
  int decision = -1;
  bool nonGreedy = false;
}
