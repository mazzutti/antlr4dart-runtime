part of antlr4dart;

/// The last node in the ATN for a rule, unless that rule is the start symbol.
/// In that case, there is one transition to EOF. Later, we might encode
/// references to all calls to this rule to compute FOLLOW sets for
/// error handling.
class RuleStopState extends AtnState {
  int get stateType => AtnState.RULE_STOP;
}
