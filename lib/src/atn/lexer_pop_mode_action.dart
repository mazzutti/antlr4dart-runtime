part of antlr4dart;

/**
 * Implements the `popMode` lexer action by calling [Lexer.popMode].
 *
 * The `popMode` command does not have any parameters, so this action is
 * implemented as a singleton instance exposed by [INSTANCE].
 */
class LexerPopModeAction implements LexerAction {
  /**
   * Provides a singleton instance of this parameterless lexer action.
   */
  static final LexerPopModeAction INSTANCE = new LexerPopModeAction._internal();

  // Constructs the singleton instance of the lexer popMode command.
  LexerPopModeAction._internal();

  /**
   * Returns [LexerActionType.POP_MODE].
   */
  LexerActionType get actionType => LexerActionType.POP_MODE;

  /**
   * Allways returns `false`.
   */
  bool get isPositionDependent => false;

  /**
   * This action is implemented by calling [Lexer.popMode].
   */
  void execute(Lexer lexer) {
    lexer.popMode();
  }

  int get hashCode {
    int hash = MurmurHash.initialize();
    hash = MurmurHash.update(hash, actionType.ordinal);
    return MurmurHash.finish(hash, 1);
  }

  bool operator ==(Object other) {
    return identical(other, this);
  }

  String toString() => "popMode";
}
