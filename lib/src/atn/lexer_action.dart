part of antlr4dart;

/**
 * Represents a single action which can be executed following the successful
 * match of a lexer rule. Lexer actions are used for both embedded action
 * syntax and antlr4dart lexer command syntax.
 */
abstract class LexerAction {
  /**
   * The serialization type of the lexer action.
   */
  LexerActionType get actionType;

  /**
   * Gets whether the lexer action is position-dependent. Position-dependent
   * actions may have different semantics depending on the [CharSource]
   * index at the time the action is executed.
   *
   * Many lexer commands, including `type`, `skip`, and `more`, do not check
   * the input index during their execution. Actions like this are position-
   * independent, and may be stored more efficiently as part of the
   * [LexerAtnConfig.lexerActionExecutor].
   *
   * This is `true` if the lexer action semantics can be affected by the
   * position of the input [CharSource] at the time it is executed;
   * otherwise, `false`.
   */
  bool get isPositionDependent;

  /**
   * Execute the lexer action in the context of the specified [Lexer].
   *
   * For position-dependent actions, the input stream must already be
   * positioned correctly prior to calling this method.
   *
   * [lexer] is the lexer instance.
   */
  void execute(Lexer lexer);
}
