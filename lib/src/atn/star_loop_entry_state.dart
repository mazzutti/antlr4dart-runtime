part of antlr4dart;

class StarLoopEntryState extends DecisionState {
  StarLoopbackState loopBackState;
  int get stateType => AtnState.STAR_LOOP_ENTRY;
}
