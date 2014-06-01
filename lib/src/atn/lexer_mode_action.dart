part of antlr4dart;

/// Implements the `mode` lexer action by calling [Lexer.mode] with
/// the assigned mode.
class LexerModeAction implements LexerAction {
  /// The lexer mode this action should transition the lexer to.
  final int mode;

  /// Constructs a new `mode` action with the specified mode value.
  /// [mode] is the mode value to pass to [Lexer.mode].
  LexerModeAction(this.mode);

  /// Return the [LexerActionType.MODE].
  LexerActionType get actionType => LexerActionType.MODE;

  /// Allways return This method returns `false`.
  bool get isPositionDependent => false;

  /// This action is implemented by calling [Lexer.mode] with the
  /// value provided by [mode].
  void execute(Lexer lexer) {
    lexer.mode = mode;
  }

  int get hashCode {
    int hash = MurmurHash.initialize();
    hash = MurmurHash.update(hash, actionType.ordinal);
    hash = MurmurHash.update(hash, mode);
    return MurmurHash.finish(hash, 2);
  }

  bool operator ==(Object other) {
    if (other is LexerModeAction) {
      return mode == other.mode;
    }
    return false;
  }

  String toString() => "mode($mode)";
}
