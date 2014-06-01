part of antlr4dart;

/// Executes a custom lexer action by calling [Recognizer.action] with the
/// rule and action indexes assigned to the custom action. The implementation of
/// a custom action is added to the generated code for the lexer in an override
/// of [Recognizer.action] when the grammar is compiled.
class LexerCustomAction implements LexerAction {
  /// The rule index to use for calls to [Recognizer.action].
  final int ruleIndex;

  /// The action index to use for calls to [Recognizer.action].
  final int actionIndex;

  /// Constructs a custom lexer action with the specified rule and action
  /// indexes.
  ///
  /// [ruleIndex] is the rule index to use for calls to [Recognizer.action].
  /// [actionIndex] is the action index to use for calls to [Recognizer.action].
  LexerCustomAction(this.ruleIndex, this.actionIndex);

  /// Returns [LexerActionType.CUSTOM].
  LexerActionType get actionType => LexerActionType.CUSTOM;

  /// Gets whether the lexer action is position-dependent. Position-dependent
  /// actions may have different semantics depending on the [CharSource]
  /// index at the time the action is executed.
  ///
  /// Custom actions are position-dependent since they may represent a
  /// user-defined embedded action which makes calls to methods like
  /// [Lexer.text].
  ///
  /// Allways returns `true`.
  bool get isPositionDependent => true;

  /// Custom actions are implemented by calling [Lexer.action] with the
  /// appropriate rule and action indexes.
  void execute(Lexer lexer) {
    lexer.action(null, ruleIndex, actionIndex);
  }

  int get hashCode {
    int hash = MurmurHash.initialize();
    hash = MurmurHash.update(hash, actionType.ordinal);
    hash = MurmurHash.update(hash, ruleIndex);
    hash = MurmurHash.update(hash, actionIndex);
    return MurmurHash.finish(hash, 3);
  }

  bool operator == (Object other) {
    if (other is LexerCustomAction) {
      return ruleIndex == other.ruleIndex
          && actionIndex == other.actionIndex;
    }
    return false;
  }
}
