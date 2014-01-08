part of antlr4dart;

/**
 * Decision state for `A+` and `(A|B)+`.  It has two transitions:
 * one to the loop back to start of the block and one to exit.
 */
class PlusLoopbackState extends DecisionState {
  int get stateType => AtnState.PLUS_LOOP_BACK;
}
