part of antlr4dart;

class StarLoopbackState extends AtnState {
  int get stateType => AtnState.STAR_LOOP_BACK;
  StarLoopEntryState get loopEntryState {
    return transition(0).target;
  }
}
