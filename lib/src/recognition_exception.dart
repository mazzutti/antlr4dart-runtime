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
   * The [Recognizer] where this exception originated.
   */
  final Recognizer _recognizer;

  final RuleContext _ctx;

  final IntSource _input;

  /**
   * The current [Token] when an error occurred. Since not all sources
   * support accessing symbols by index, we have to track the [Token]
   * instance itself.
   */
  Token _offendingToken;

  int _offendingState = -1;

  String message;

  RecognitionException(this._recognizer,
                       this._input,
                       this._ctx) {
    if (_recognizer != null) _offendingState = _recognizer.state;
  }

  RecognitionException.withMessage(this.message,
                                   this._recognizer,
                                   this._input,
                                   this._ctx) {
    if (_recognizer != null) _offendingState = _recognizer.state;
  }

  /**
   * Get the ATN state number the parser was in at the time the error
   * occurred. For [NoViableAltException] and [LexerNoViableAltException]
   * exceptions, this is the [DecisionState] number. For others, it is
   * the state whose outgoing edge we couldn't match.
   *
   * If the state number is not known, this method returns `-1`.
   */
  int get offendingState => _offendingState;

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
    if (_recognizer != null) {
      return _recognizer.atn.getExpectedTokens(_offendingState, _ctx);
    }
    return null;
  }

  /**
   * Gets the [RuleContext] at the time this exception was thrown.
   *
   * If the context is not available, this method returns `null`.
   *
   * Return the [RuleContext] at the time this exception was thrown.
   * If the context is not available, this method returns `null`.
   */
  RuleContext get context => _ctx;

  /**
   * Gets the input source which is the symbol source for the recognizer where
   * this exception was thrown.
   *
   * If the input source is not available, this method returns `null`.
   *
   * Return The input source which is the symbol source for the recognizer
   * where this exception was thrown, or `null` if the source is not
   * available.
   */
  IntSource get inputSource => _input;

  Token get offendingToken => _offendingToken;

  /**
   * Gets the [Recognizer] where this exception occurred.
   *
   * If the recognizer is not available, this method returns `null`.
   *
   * Return the recognizer where this exception occurred, or `null` if
   * the recognizer is not available.
   */
  Recognizer get recognizer => _recognizer;
}
