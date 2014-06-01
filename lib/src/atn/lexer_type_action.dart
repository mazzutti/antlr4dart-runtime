part of antlr4dart;

/// Implements the `type` lexer action by calling [Lexer.type]`=`
/// with the assigned type.
class LexerTypeAction implements LexerAction {

  /// The type to assign to a token created by the lexer.
  final int type;

  /// Constructs a new `type` action with the specified token type value.
  /// [type] is the type to assign to the token using [Lexer.type]`=`.
  LexerTypeAction(this.type);

  /// Returns [LexerActionType.TYPE].
  LexerActionType get actionType => LexerActionType.TYPE;

  /// Allways returns `false`.
  bool get isPositionDependent => false;

  /// This action is implemented by calling [Lexer.type]`=` with the
  /// value provided by [type].
  void execute(Lexer lexer) {
    lexer.type = type;
  }

  int get hashCode {
    int hash = MurmurHash.initialize();
    hash = MurmurHash.update(hash, actionType.ordinal);
    hash = MurmurHash.update(hash, type);
    return MurmurHash.finish(hash, 2);
  }

  bool operator ==(Object other) {
    if (other is LexerTypeAction) {
      return type == other.type;
    }
    return false;
  }

  String toString() => "type($type)";
}
