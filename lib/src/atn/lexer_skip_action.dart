part of antlr4dart;

/**
 * Implements the `skip` lexer action by calling [Lexer.skip].
 *
 * The `skip` command does not have any parameters, so this action is
 * implemented as a singleton instance exposed by [INSTANCE].
 */
class LexerSkipAction implements LexerAction {
  /**
   * Provides a singleton instance of this parameterless lexer action.
   */
  static final LexerSkipAction INSTANCE = new LexerSkipAction._internal();

  // Constructs the singleton instance of the lexer skip command.
  LexerSkipAction._internal();

  /**
   * Returns [LexerActionType.SKIP].
   */
  LexerActionType get actionType => LexerActionType.SKIP;

  /**
   * {@inheritDoc}
   * Allways returns `false`.
   */
  bool get isPositionDependent => false;

  /**
   * This action is implemented by calling [Lexer.skip].
   */
  void execute(Lexer lexer) {
    lexer.skip();
  }

  int get hashCode {
    int hash = MurmurHash.initialize();
    hash = MurmurHash.update(hash, actionType.ordinal);
    return MurmurHash.finish(hash, 1);
  }

  bool operator ==(Object other) {
    return identical(other, this);
  }

  String toString() => "skip";
}
