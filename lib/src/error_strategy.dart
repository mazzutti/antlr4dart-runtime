part of antlr4dart;

/**
 * The interface for defining strategies to deal with syntax errors encountered
 * during a parse by antlr4dart-generated parsers. We distinguish between three
 * different kinds of errors:
 *
 * * The parser could not figure out which path to take in the ATN (none of
 *   the available alternatives could possibly match)
 * * The current input does not match what we were looking for.
 * * A predicate evaluated to false.
 *
 * Implementations of this interface report syntax errors by calling
 * [Parser.notifyErrorListeners].
 */
abstract class ErrorStrategy {
  /**
   * Reset the error handler state for the specified `recognizer`.
   */
  void reset(Parser recognizer);

  /**
   * This method is called when an unexpected symbol is encountered during an
   * inline match operation, such as [Parser.match]. If the error
   * strategy successfully recovers from the match failure, this method
   * returns the [Token] instance which should be treated as the
   * successful result of the match.
   *
   * Note that the calling code will not report an error if this method
   * returns successfully. The error strategy implementation is responsible
   * for calling [Parser.notifyErrorListener] as appropriate.
   *
   * [recognizer] is the parser instance.
   * Throws [RecognitionException] if the error strategy was not able to
   * recover from the unexpected input symbol.
   */
  Token recoverInline(Parser recognizer);

  /**
   * This method is called to recover from exception `e`. This method is
   * called after [reportError] by the default exception handler
   * generated for a rule method.
   *
   * [recognizer] is the parser instance.
   * [e] is the recognition exception to recover from.
   * Throws [RecognitionException] if the error strategy could not recover from
   * the recognition exception
   */
  void recover(Parser recognizer, RecognitionException e);

  /**
   * This method provides the error handler with an opportunity to handle
   * syntactic or semantic errors in the input source before they result in a
   * [RecognitionException].
   *
   * The generated code currently contains calls to [sync] after
   * entering the decision state of a closure block (`(...)*` or
   * `(...)+`).
   *
   * For an implementation based on Jim Idle's "magic sync" mechanism, see
   * [DefaultErrorStrategy.sync].
   *
   * [recognizer] is the parser instance.
   * Throws [RecognitionException] if an error is detected by the error
   * strategy but cannot be automatically recovered at the current state in
   * the parsing process
   */
  void sync(Parser recognizer);

  /**
   * Tests whether or not `recognizer` is in the process of recovering
   * from an error. In error recovery mode, [Parser.consume] adds
   * symbols to the parse tree by calling
   * [ParserRuleContext.addErrorNode]`(`[Token]`)` instead of
   * [ParserRuleContext.addChild]`(`[Token]`)`.
   *
   * [recognizer] is the parser instance.
   * Return `true` if the parser is currently recovering from a parse
   * error, otherwise `false`.
   */
  bool inErrorRecoveryMode(Parser recognizer);

  /**
   * This method is called by when the parser successfully matches an input
   * symbol.
   *
   * [recognizer] is the parser instance.
   */
  void reportMatch(Parser recognizer);

  /**
   * Report any kind of [RecognitionException]. This method is called by
   * the default exception handler generated for a rule method.
   *
   * [recognizer] is the parser instance.
   * [e] is the recognition exception to report.
   */
  void reportError(Parser recognizer, RecognitionException e);
}
