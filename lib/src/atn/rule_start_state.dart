part of antlr4dart;

class RuleStartState extends AtnState {
  RuleStopState stopState;
  int get stateType => AtnState.RULE_START;
}
