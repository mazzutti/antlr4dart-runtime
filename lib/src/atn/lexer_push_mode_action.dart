part of antlr4dart;

/// Implements the `pushMode` lexer action by calling
/// [Lexer.pushMode] with the assigned mode.
class LexerPushModeAction implements LexerAction {

  /// The lexer mode this action should transition the lexer to.
  final int mode;

  /// Constructs a new `pushMode` action with the specified mode value.
  /// [mode] is the mode value to pass to [Lexer.pushMode].
  LexerPushModeAction(this.mode);

  /// Returns [LexerActionType.PUSH_MODE].
  LexerActionType get actionType => LexerActionType.PUSH_MODE;

  /// Allways returns `false`.
  bool get isPositionDependent=> false;

  /// This action is implemented by calling [Lexer.pushMode] with the
  /// value provided by [mode].
  void execute(Lexer lexer) {
    lexer.pushMode(mode);
  }

  int get hashCode {
    int hash = MurmurHash.initialize();
    hash = MurmurHash.update(hash, actionType.ordinal);
    hash = MurmurHash.update(hash, mode);
    return MurmurHash.finish(hash, 2);
  }

  bool operator ==(Object other) {
    if (other is LexerPushModeAction) {
      return mode == other.mode;

    }
    return false;
  }

  String toString() => "pushMode($mode)";
}
