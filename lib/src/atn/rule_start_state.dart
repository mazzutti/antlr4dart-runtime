part of antlr4dart;

class RuleStartState extends AtnState {
  RuleStopState stopState;
  bool isPrecedenceRule = false;
  int get stateType => AtnState.RULE_START;
}
