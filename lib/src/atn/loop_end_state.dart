part of antlr4dart;

/// Mark the end of a * or + loop.
class LoopEndState extends AtnState {
  AtnState loopBackState;
  int get stateType => AtnState.LOOP_END;
}
