part of antlr4dart;

/// This implementation of [LexerAction] is used for tracking input offsets
/// for position-dependent actions within a [LexerActionExecutor].
///
/// This action is not serialized as part of the ATN, and is only required for
/// position-dependent lexer actions which appear at a location other than the
/// end of a rule. For more information about DFA optimizations employed for
/// lexer actions, see [LexerActionExecutor.append] and
/// [LexerActionExecutor.fixOffsetBeforeMatch].
class LexerIndexedCustomAction implements LexerAction {

  /// the location in the input [CharSource] at which the lexer
  /// action should be executed. The value is interpreted as an offset
  /// relative to the token start index.
  final int offset;

  /// The lexer action to execute.
  final LexerAction action;

  /// Constructs a new indexed custom action by associating a character offset
  /// with a [LexerAction].
  ///
  /// Note: This class is only required for lexer actions for which
  /// [LexerAction.isPositionDependent] returns `true`.
  ///
  /// [offset] is the offset into the input [CharSource], relative to
  /// the token start index, at which the specified lexer action should be
  /// executed.
  /// [action] is the lexer action to execute at a particular offset in the
  /// input [CharSource].
  LexerIndexedCustomAction(this.offset, this.action);

  /// The result of access the [actionType] getter
  /// on the [LexerAction] returned by [action].
  LexerActionType get actionType => action.actionType;

  /// Allways returns `true`.
  bool get isPositionDependent => true;

  /// This method calls [execute] on the result of [action]
  /// using the provided [lexer].
  void execute(Lexer lexer) {
    // assume the input stream position was properly set by the calling code
    action.execute(lexer);
  }

  int get hashCode {
    int hash = MurmurHash.initialize();
    hash = MurmurHash.update(hash, offset);
    hash = MurmurHash.update(hash, action.hashCode);
    return MurmurHash.finish(hash, 2);
  }

  bool operator ==(Object other) {
    if (other is LexerIndexedCustomAction) {
      return offset == other.offset && action == other.action;
    }
    return false;
  }

}
