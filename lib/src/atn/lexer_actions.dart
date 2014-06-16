part of antlr4dart;

/// Represents the serialization type of a [LexerAction].
class LexerActionType {
  /// The type of a [LexerChannelAction] action.
  static const LexerActionType CHANNEL = const LexerActionType._internal(0);

  /// The type of a [LexerCustomAction] action.
  static const LexerActionType CUSTOM = const LexerActionType._internal(1);

  /// The type of a [LexerModeAction] action.
  static const LexerActionType MODE = const LexerActionType._internal(2);

  /// The type of a [LexerMoreAction] action.
  static const LexerActionType MORE = const LexerActionType._internal(3);

  /// The type of a [LexerPopModeAction] action.
  static const LexerActionType POP_MODE = const LexerActionType._internal(4);

  /// The type of a [LexerPushModeAction] action.
  static const LexerActionType PUSH_MODE = const LexerActionType._internal(5);

  /// The type of a LexerSkipAction] action.
  static const LexerActionType SKIP = const LexerActionType._internal(6);

  /// The type of a [LexerTypeAction] action.
  static const LexerActionType TYPE = const LexerActionType._internal(7);

  static List<LexerActionType> values = [
    CHANNEL, CUSTOM, MODE, MORE, POP_MODE, PUSH_MODE, SKIP, TYPE
  ];

  final int ordinal;

  const LexerActionType._internal(this.ordinal);
}

/// Represents a single action which can be executed following the successful
/// match of a lexer rule. Lexer actions are used for both embedded action
/// syntax and antlr4dart lexer command syntax.
abstract class LexerAction {
  /// The serialization type of the lexer action.
  LexerActionType get actionType;

  /// Gets whether the lexer action is position-dependent. Position-dependent
  /// actions may have different semantics depending on the [StringSource]
  /// index at the time the action is executed.
  ///
  /// Many lexer commands, including `type`, `skip`, and `more`, do not check
  /// the input index during their execution. Actions like this are position-
  /// independent, and may be stored more efficiently as part of the
  /// [LexerAtnConfig.lexerActionExecutor].
  ///
  /// This is `true` if the lexer action semantics can be affected by the
  /// position of the input [StringSource] at the time it is executed;
  /// otherwise, `false`.
  bool get isPositionDependent;

  /// Execute the lexer action in the context of the specified [Lexer].
  ///
  /// For position-dependent actions, the input stream must already be
  /// positioned correctly prior to calling this method.
  ///
  /// [lexer] is the lexer instance.
  void execute(Lexer lexer);
}

/// Implements the `channel` lexer action by calling
/// [Lexer.channel]`=` with the assigned channel.
class LexerChannelAction implements LexerAction {

  /// The channel to use for the [Token] created by the lexer.
  final int channel;

  /// Constructs a new [channel] action with the specified channel value.
  /// [channel] is the channel value to pass to [Lexer.channel]`=`.
  LexerChannelAction(this.channel);

  /// Returns [LexerActionType.CHANNEL].
  LexerActionType get actionType => LexerActionType.CHANNEL;

  /// Always returns `false`.
  bool get isPositionDependent=> false;

  /// This action is implemented by calling [Lexer.channel]`=` with the
  /// value provided by [channel].
  void execute(Lexer lexer) {
    lexer.channel = channel;
  }

  int get hashCode {
    int hash = MurmurHash.initialize();
    hash = MurmurHash.update(hash, actionType.ordinal);
    hash = MurmurHash.update(hash, channel);
    return MurmurHash.finish(hash, 2);
  }

  bool operator ==(Object other) {
    return other is LexerChannelAction && channel == other.channel;
  }

  String toString() => "channel($channel)";
}

/// Implements the `more` lexer action by calling [Lexer.more].
///
/// The `more` command does not have any parameters, so this action is
/// implemented as a singleton instance exposed by [INSTANCE].
class LexerMoreAction implements LexerAction {
  /// Provides a singleton instance of this parameterless lexer action.
  static final LexerMoreAction INSTANCE = new LexerMoreAction._internal();

  // Constructs the singleton instance of the lexer more command.
  LexerMoreAction._internal();

  /// Returns [LexerActionType.MORE].
  LexerActionType get actionType => LexerActionType.MORE;

  /// Allways returns `false`.
  bool get isPositionDependent => false;

  /// This action is implemented by calling [Lexer.more].
  void execute(Lexer lexer) {
    lexer.more();
  }

  int get hashCode {
    int hash = MurmurHash.initialize();
    hash = MurmurHash.update(hash, actionType.ordinal);
    return MurmurHash.finish(hash, 1);
  }

  bool operator ==(Object other) => identical(this, other);

  String toString() => "more";
}

/// Implements the `skip` lexer action by calling [Lexer.skip].
///
/// The `skip` command does not have any parameters, so this action is
/// implemented as a singleton instance exposed by [INSTANCE].
class LexerSkipAction implements LexerAction {
  /// Provides a singleton instance of this parameterless lexer action.
  static final LexerSkipAction INSTANCE = new LexerSkipAction._internal();

  // Constructs the singleton instance of the lexer skip command.
  LexerSkipAction._internal();

  /// Returns [LexerActionType.SKIP].
  LexerActionType get actionType => LexerActionType.SKIP;

  /// Allways returns `false`.
  bool get isPositionDependent => false;

  /// This action is implemented by calling [Lexer.skip].
  void execute(Lexer lexer) {
    lexer.skip();
  }

  int get hashCode {
    int hash = MurmurHash.initialize();
    hash = MurmurHash.update(hash, actionType.ordinal);
    return MurmurHash.finish(hash, 1);
  }

  bool operator ==(Object other) => identical(other, this);

  String toString() => "skip";
}

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
    return other is LexerModeAction && mode == other.mode;
  }

  String toString() => "mode($mode)";
}

/// Implements the `popMode` lexer action by calling [Lexer.popMode].
///
/// The `popMode` command does not have any parameters, so this action is
/// implemented as a singleton instance exposed by [INSTANCE].
class LexerPopModeAction implements LexerAction {
  /// Provides a singleton instance of this parameterless lexer action.
  static final LexerPopModeAction INSTANCE = new LexerPopModeAction._internal();

  // Constructs the singleton instance of the lexer popMode command.
  LexerPopModeAction._internal();

  /// Returns [LexerActionType.POP_MODE].
  LexerActionType get actionType => LexerActionType.POP_MODE;

  /// Allways returns `false`.
  bool get isPositionDependent => false;

  /// This action is implemented by calling [Lexer.popMode].
  void execute(Lexer lexer) {
    lexer.popMode();
  }

  int get hashCode {
    int hash = MurmurHash.initialize();
    hash = MurmurHash.update(hash, actionType.ordinal);
    return MurmurHash.finish(hash, 1);
  }

  bool operator ==(Object other) => identical(other, this);

  String toString() => "popMode";
}

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
    return other is LexerPushModeAction &&mode == other.mode;
  }

  String toString() => "pushMode($mode)";
}

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
    return other is LexerTypeAction && type == other.type;
  }

  String toString() => "type($type)";
}

/// Executes a custom lexer action by calling [Recognizer.action] with the
/// rule and action indexes assigned to the custom action.
///
/// The implementation of a custom action is added to the generated code for
/// the lexer in an override of [Recognizer.action] when the grammar is
/// compiled.
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
  /// actions may have different semantics depending on the [StringSource]
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
    return other is LexerCustomAction
        && ruleIndex == other.ruleIndex
        && actionIndex == other.actionIndex;
  }
}

/// This implementation of [LexerAction] is used for tracking input offsets
/// for position-dependent actions within a [LexerActionExecutor].
///
/// This action is not serialized as part of the ATN, and is only required for
/// position-dependent lexer actions which appear at a location other than the
/// end of a rule. For more information about DFA optimizations employed for
/// lexer actions, see [LexerActionExecutor.append] and
/// [LexerActionExecutor.fixOffsetBeforeMatch].
class LexerIndexedCustomAction implements LexerAction {

  /// the location in the input [StringSource] at which the lexer
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
  /// [offset] is the offset into the input [StringSource], relative to
  /// the token start index, at which the specified lexer action should be
  /// executed.
  /// [action] is the lexer action to execute at a particular offset in the
  /// input [StringSource].
  LexerIndexedCustomAction(this.offset, this.action);

  /// The result of access the [actionType] getter on the [LexerAction]
  /// returned by [action].
  LexerActionType get actionType => action.actionType;

  /// Allways returns `true`.
  bool get isPositionDependent => true;

  /// This method calls [execute] on the result of [action] using the
  /// provided [lexer].
  void execute(Lexer lexer) {
    action.execute(lexer);
  }

  int get hashCode {
    int hash = MurmurHash.initialize();
    hash = MurmurHash.update(hash, offset);
    hash = MurmurHash.update(hash, action.hashCode);
    return MurmurHash.finish(hash, 2);
  }

  bool operator ==(Object other) {
    return other is LexerIndexedCustomAction
        && offset == other.offset
        && action == other.action;
  }
}

/// Represents an executor for a sequence of lexer actions which traversed
/// during the matching operation of a lexer rule (token).
///
/// The executor tracks position information for position-dependent lexer
/// actions efficiently, ensuring that actions appearing only at the end of
/// the rule do not cause bloating of the DFA created for the lexer.
class LexerActionExecutor {

  /// The lexer actions to be executed by this executor.
  final List<LexerAction> lexerActions;

  // Caches the result of hashCode since the hash code is an element
  // of the performance-critical LexerAtnConfig.hashCode operation.
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

  int get hashCode => _hashCode;

  /// Creates a [LexerActionExecutor] which executes the actions for
  /// the input [lexerActionExecutor] followed by a specified [lexerAction].
  ///
  /// [lexerActionExecutor] is the executor for actions already traversed by
  /// the lexer while matching a token within a particular
  /// [LexerAtnConfig]. If this is `null`, the method behaves as
  /// though it were an empty executor.
  /// [lexerAction] is the lexer action to execute after the actions
  /// specified in [lexerActionExecutor].
  ///
  /// Return A [LexerActionExecutor] for executing the combine actions
  /// of [lexerActionExecutor] and [lexerAction].
  static LexerActionExecutor append(LexerActionExecutor lexerActionExecutor,
                                    LexerAction lexerAction) {
    if (lexerActionExecutor == null) {
      return new LexerActionExecutor([lexerAction]);
    }
    var lexerActions = new List<LexerAction>.from(
        lexerActionExecutor.lexerActions, growable: true)..add(lexerAction);
    return new LexerActionExecutor(lexerActions);
  }

  /// Creates a [LexerActionExecutor] which encodes the current offset
  /// for position-dependent lexer actions.
  ///
  /// Normally, when the executor encounters lexer actions where
  /// [LexerAction.isPositionDependent] returns `true`, it calls
  /// [InputSource.seek] on the input [StringSource] to set the input
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
      if (lexerActions[i].isPositionDependent
          && lexerActions[i] is! LexerIndexedCustomAction) {
        if (updatedLexerActions == null) {
          updatedLexerActions = new List<LexerAction>.from(lexerActions);
        }
        updatedLexerActions[i] =
            new LexerIndexedCustomAction(offset, lexerActions[i]);
      }
    }
    if (updatedLexerActions == null) return this;
    return new LexerActionExecutor(updatedLexerActions);
  }

  /// Execute the actions encapsulated by this executor within the context of a
  /// particular [Lexer].
  ///
  /// This method calls [IntSource.seek] to set the position of the [input]
  /// [CharSource] prior to calling [LexerAction.execute] on a
  /// position-dependent action. Before the method returns, the input
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
  void execute(Lexer lexer, StringSource input, int startIndex) {
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
    } finally {
      if (requiresSeek) {
        input.seek(stopIndex);
      }
    }
  }

  bool operator == (Object other) {
    return other is LexerActionExecutor
        && hashCode == other.hashCode
        && new ListEquality().equals(lexerActions, other.lexerActions);
  }
}

