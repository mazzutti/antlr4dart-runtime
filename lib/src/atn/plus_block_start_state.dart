part of antlr4dart

;/// Start of `(A|B|...)+` loop. Technically a decision state, but
/// we don't use for code generation; somebody might need it, so I'm defining
/// it for completeness. In reality, the [PlusLoopbackState] node is the
/// real decision-making note for `A+`.
class PlusBlockStartState extends BlockStartState {
  PlusLoopbackState loopBackState;
  int get stateType => AtnState.PLUS_BLOCK_START;
}
