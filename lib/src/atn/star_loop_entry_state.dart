part of antlr4dart;

class StarLoopEntryState extends DecisionState {
  StarLoopbackState loopBackState;

  /// Indicates whether this state can benefit from a precedence Dfa
  /// during SLL decision making.
  ///
  /// This is a computed property that is calculated during ATN
  /// deserialization and stored for use in [ParserAtnSimulator] and
  /// [ParserInterpreter].
  bool precedenceRuleDecision = false;

  int get stateType => AtnState.STAR_LOOP_ENTRY;
}
