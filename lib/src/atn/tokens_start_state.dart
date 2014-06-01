part of antlr4dart;

/// The Tokens rule start state linking to each lexer rule start state.
class TokensStartState extends DecisionState {
  int get stateType => AtnState.TOKEN_START;
}
