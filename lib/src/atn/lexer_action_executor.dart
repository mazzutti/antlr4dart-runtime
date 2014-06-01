part of antlr4dart;

/// Represents an executor for a sequence of lexer actions which
/// traversed during the matching operation of a lexer rule (token).
///
/// The executor tracks position information for position-dependent lexer actions
/// efficiently, ensuring that actions appearing only at the end of the rule do
/// not cause bloating of the [Dfa] created for the lexer.
class LexerActionExecutor {

  /// The lexer actions to be executed by this executor.
  final List<LexerAction> lexerActions;

  /// Caches the result of [hashCode] since the hash code is an element
  /// of the performance-critical [LexerAtnConfig.hashCode] operation.
  int _hashCode;

  /// Constructs an executor for a sequence of [LexerAction] actions.
  /// [lexerActions] is the lexer actions to execute.
  LexerActionExecutor(this.lexerActions) {
    int hash = MurmurHash.initialize();
    for (LexerAction lexerAction in lexerActions) {
      hash = MurmurHash.update(hash, lexerAction.hashCode);
    }
    _hashCode = MurmurHash.finish(hash, lexerActions.length);
  }

  /// Creates a [LexerActionExecutor] which executes the actions for
  /// the input [lexerActionExecutor] followed by a specified
  /// [lexerAction].
  ///
  /// [lexerActionExecutor] is the executor for actions already traversed by
  /// the lexer while matching a token within a particular
  /// [LexerAtnConfig]. If this is `null`, the method behaves as
  /// though it were an empty executor.
  /// [lexerAction] is the lexer action to execute after the actions
  /// specified in [lexerActionExecutor].
  ///
  /// Return A [LexerActionExecutor] for executing the combine actions
  /// of [lexerActionExecutor] and [lexerAction.
  static LexerActionExecutor append(LexerActionExecutor lexerActionExecutor, LexerAction lexerAction) {
    if (lexerActionExecutor == null) {
      return new LexerActionExecutor([lexerAction]);
    }
    List<LexerAction> lexerActions = new List<LexerAction>.from(lexerActionExecutor.lexerActions, growable: true);
    lexerActions.add(lexerAction);
    return new LexerActionExecutor(lexerActions);
  }

  /// Creates a [LexerActionExecutor] which encodes the current offset
  /// for position-dependent lexer actions.
  ///
  /// Normally, when the executor encounters lexer actions where
  /// [LexerAction.isPositionDependent] returns `true`, it calls
  /// [IntSource.seek] on the input [CharSource] to set the input
  /// position to the **end** of the current token. This behavior provides
  /// for efficient DFA representation of lexer actions which appear at the end
  /// of a lexer rule, even when the lexer rule matches a variable number of
  /// characters.
  ///
  /// Prior to traversing a match transition in the ATN, the current offset
  /// from the token start index is assigned to all position-dependent lexer
  /// actions which have not already been assigned a fixed offset. By storing
  /// the offsets relative to the token start index, the DFA representation of
  /// lexer actions which appear in the middle of tokens remains efficient due
  /// to sharing among tokens of the same length, regardless of their absolute
  /// position in the input stream.
  ///
  /// If the current executor already has offsets assigned to all
  /// position-dependent lexer actions, the method returns `this`.
  ///
  /// [offset] is the current offset to assign to all position-dependent
  /// lexer actions which do not already have offsets assigned.
  ///
  /// Return a [LexerActionExecutor] which stores input stream offsets
  /// for all position-dependent lexer actions.
  LexerActionExecutor fixOffsetBeforeMatch(int offset) {
    List<LexerAction> updatedLexerActions = null;
    for (int i = 0; i < lexerActions.length; i++) {
      if (lexerActions[i].isPositionDependent && lexerActions[i] is! LexerIndexedCustomAction) {
        if (updatedLexerActions == null) {
          updatedLexerActions = new List<LexerAction>.from(lexerActions);
        }
        updatedLexerActions[i] = new LexerIndexedCustomAction(offset, lexerActions[i]);
      }
    }
    if (updatedLexerActions == null) return this;
    return new LexerActionExecutor(updatedLexerActions);
  }

  /// Execute the actions encapsulated by this executor within the context of a
  /// particular [Lexer].
  /// This method calls [IntSource.seek] to set the position of the
  /// [input] [CharSource] prior to calling [LexerAction.execute] on
  /// a position-dependent action. Before the method returns, the input
  /// position will be restored to the same position it was in when the
  /// method was invoked.
  ///
  /// [lexer] is the lexer instance.
  /// [input] is the input stream which is the source for the current token.
  /// When this method is called, the current [IntSource.index] for
  /// [input] should be the start of the following token, i.e. 1
  /// character past the end of the current token.
  /// [startIndex] is the token start index. This value may be passed to
  /// [IntSource.seek] to set the [input] position to the beginning
  /// of the token.
  void execute(Lexer lexer, CharSource input, int startIndex) {
    bool requiresSeek = false;
    int stopIndex = input.index;
    try {
      for (LexerAction lexerAction in lexerActions) {
        if (lexerAction is LexerIndexedCustomAction) {
          int offset = (lexerAction as LexerIndexedCustomAction).offset;
          input.seek(startIndex + offset);
          lexerAction = (lexerAction as LexerIndexedCustomAction).action;
          requiresSeek = (startIndex + offset) != stopIndex;
        } else if (lexerAction.isPositionDependent) {
          input.seek(stopIndex);
          requiresSeek = false;
        }
        lexerAction.execute(lexer);
      }
    }
    finally {
      if (requiresSeek) {
        input.seek(stopIndex);
      }
    }
  }

  int get hashCode => _hashCode;

  bool operator == (Object other) {
    if (other is LexerActionExecutor) {
      ListEquality listEquality = new ListEquality();
      return _hashCode == other._hashCode
        && listEquality.equals(lexerActions, other.lexerActions);
    }
    return false;
  }
}
