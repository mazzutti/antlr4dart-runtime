part of antlr4dart;

/**
 * Implements the `more` lexer action by calling [Lexer.more].
 *
 * The `more` command does not have any parameters, so this action is
 * implemented as a singleton instance exposed by [INSTANCE].
 */
class LexerMoreAction implements LexerAction {
  /**
   * Provides a singleton instance of this parameterless lexer action.
   */
  static final LexerMoreAction INSTANCE = new LexerMoreAction._internal();

  // Constructs the singleton instance of the lexer more command.
  LexerMoreAction._internal();

  /**
   * Returns [LexerActionType.MORE].
   */
  LexerActionType get actionType => LexerActionType.MORE;

  /**
   * Allways returns `false`.
   */
  bool get isPositionDependent => false;

  /**
   * This action is implemented by calling [Lexer.more].
   */
  void execute(Lexer lexer) {
    lexer.more();
  }

  int get hashCode {
    int hash = MurmurHash.initialize();
    hash = MurmurHash.update(hash, actionType.ordinal);
    return MurmurHash.finish(hash, 1);
  }

  bool operator ==(Object other) {
    return identical(this, other);
  }

  String toString() => "more";
}
