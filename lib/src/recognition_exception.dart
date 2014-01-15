part of antlr4dart;

/**
 * The root of the antlr4dart exception hierarchy. In general, antlr4dart tracks
 * just 3 kinds of errors: prediction errors, failed predicate errors, and
 * mismatched input errors. In each case, the parser knows where it is
 * in the input, where it is in the ATN, the rule invocation stack,
 * and what kind of problem occurred.
 */
class RecognitionException implements Exception {
  /**
   * Gets the [Recognizer] where this exception occurred.
   *
   * If the recognizer is not available, this is `null`.
   */
  final Recognizer recognizer;

  /**
   * The [RuleContext] at the time this exception was thrown.
   */
  final RuleContext context;

  /**
   * the input source which is the symbol source for the recognizer where
   * this exception was thrown.
   */
  final IntSource inputSource;

  /**
   * The current [Token] when an error occurred. Since not all sources
   * support accessing symbols by index, we have to track the [Token]
   * instance itself.
   */
  Token offendingToken;

  /**
   * The ATN state number the parser was in at the time the error
   * occurred. For [NoViableAltException] and [LexerNoViableAltException]
   * exceptions, this is the [DecisionState] number. For others, it is
   * the state whose outgoing edge we couldn't match.
   *
   * If the state number is not known, this will be `-1`.
   */
  int offendingState = -1;

  String message;

  RecognitionException(Recognizer recognizer,
                       this.inputSource,
                       this.context) 
      : offendingState = (recognizer != null) ? recognizer.state : null,
      this.recognizer = recognizer;

  RecognitionException.withMessage(this.message,
                                   Recognizer recognizer,
                                   this.inputSource,
                                   this.context) 
      : offendingState = (recognizer != null) ? recognizer.state : null,
      this.recognizer = recognizer;

  /**
   * Gets the set of input symbols which could potentially follow the
   * previously matched symbol at the time this exception was thrown.
   *
   * If the set of expected tokens is not known and could not be computed,
   * this method returns `null`.
   *
   * Return the set of token types that could potentially follow the current
   * state in the ATN, or `null` if the information is not available.
   */
  IntervalSet get expectedTokens {
    if (recognizer != null) {
      return recognizer.atn.getExpectedTokens(offendingState, context);
    }
    return null;
  }
}
