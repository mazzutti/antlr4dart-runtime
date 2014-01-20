part of antlr4dart;

/**
 * Represents the serialization type of a [LexerAction].
 */
class LexerActionType {
  /**
   * The type of a [LexerChannelAction] action.
   */
  static const LexerActionType CHANNEL = const LexerActionType._internal(0);
  /**
   * The type of a [LexerCustomAction] action.
   */
  static const LexerActionType CUSTOM = const LexerActionType._internal(1);
  /**
   * The type of a [LexerModeAction] action.
   */
  static const LexerActionType MODE = const LexerActionType._internal(2);
  /**
   * The type of a [LexerMoreAction] action.
   */
  static const LexerActionType MORE = const LexerActionType._internal(3);
  /**
   * The type of a [LexerPopModeAction] action.
   */
  static const LexerActionType POP_MODE = const LexerActionType._internal(4);

  /**
   * The type of a [LexerPushModeAction] action.
   */
  static const LexerActionType PUSH_MODE = const LexerActionType._internal(5);

  /**
   * The type of a LexerSkipAction] action.
   */
  static const LexerActionType SKIP = const LexerActionType._internal(6);

  /**
   * The type of a [LexerTypeAction] action.
   */
  static const LexerActionType TYPE = const LexerActionType._internal(7);

  static List<LexerActionType> values = [
    CHANNEL, CUSTOM, MODE, MORE, POP_MODE, PUSH_MODE, SKIP, TYPE
  ];

  final int ordinal;

  const LexerActionType._internal(this.ordinal);
}
