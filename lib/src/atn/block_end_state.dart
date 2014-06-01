part of antlr4dart;

/// Terminal node of a simple `(a|b|c)` block.
class BlockEndState extends AtnState {
  BlockStartState startState;
  int get stateType => AtnState.BLOCK_END;
}
