part of antlr4dart;

/// The root of the antlr4dart exception hierarchy.
///
/// In general, antlr4dart tracks just 3 kinds of errors: prediction errors,
/// failed predicate errors, and mismatched input errors. In each case, the
/// parser knows where it is in the input, where it is in the ATN, the rule
/// invocation stack, and what kind of problem occurred.
class RecognitionException implements Exception {

  /// The [Recognizer] where this exception occurred.
  ///
  /// If the recognizer is not available, this is `null`.
  final Recognizer recognizer;

  /// The [RuleContext] at the time this exception was thrown.
  final RuleContext context;

  /// The input source which is the symbol source for the recognizer where
  /// this exception was thrown.
  final InputSource inputSource;

  /// The current [Token] when an error occurred. Since not all sources
  /// support accessing symbols by index, we have to track the [Token]
  /// instance itself.
  Token offendingToken;

  /// The ATN state number the parser was in at the time the error
  /// occurred.
  ///
  /// For [NoViableAltException] and [LexerNoViableAltException] exceptions,
  /// this is the [DecisionState] number. For others, it is the state whose
  /// outgoing edge we couldn't match.
  ///
  /// If the state number is not known, this will be `-1`.
  int offendingState = -1;

  String message;

  RecognitionException(this.recognizer,
                       this.inputSource,
                       this.context,
                       [this.message]) {
    offendingState = (recognizer != null) ? recognizer.state : null;
  }

  /// Gets the set of input symbols which could potentially follow the
  /// previously matched symbol at the time this exception was thrown.
  ///
  /// If the set of expected tokens is not known and could not be computed,
  /// this method returns `null`.
  ///
  /// Return the set of token types that could potentially follow the current
  /// state in the ATN, or `null` if the information is not available.
  IntervalSet get expectedTokens {
    if (recognizer != null) {
      return recognizer.atn.getExpectedTokens(offendingState, context);
    }
    return null;
  }
}

/// A semantic predicate failed during validation.
///
/// Validation of predicates occurs when normally parsing the alternative
/// just like matching a token.
///
/// Disambiguating predicate evaluation occurs when we test a predicate during
/// prediction.
class FailedPredicateException extends RecognitionException {

  final int ruleIndex;
  final int predicateIndex;
  final String predicate;

  FailedPredicateException(Parser recognizer, [String predicate, String message])
      : predicate = predicate,
        ruleIndex = _ruleIndex(recognizer),
        predicateIndex = _predicateIndex(recognizer),
        super(recognizer,
              recognizer.inputSource,
              recognizer.context,
              _formatMessage(predicate, message)){
    offendingToken = recognizer.currentToken;
  }

  static int _predicateIndex(Parser recognizer) {
    AtnState atnState = recognizer.interpreter.atn.states[recognizer.state];
    AbstractPredicateTransition transition = atnState.getTransition(0);
    return (transition is PredicateTransition) ? transition.predIndex : 0;
  }

  static int _ruleIndex(Parser recognizer) {
    AtnState atnState = recognizer.interpreter.atn.states[recognizer.state];
    AbstractPredicateTransition transition = atnState.getTransition(0);
    return (transition is PredicateTransition) ? transition.ruleIndex : 0;
  }

  static String _formatMessage(String predicate, String message) {
    return (message != null) ? message : "failed predicate: {$predicate}?";
  }
}

/// This signifies any kind of mismatched input exceptions such as when the
/// current input does not match the expected token.
class InputMismatchException extends RecognitionException {
  InputMismatchException(Parser recognizer)
      : super(recognizer, recognizer.inputSource, recognizer.context) {
    offendingToken = recognizer.currentToken;
  }
}

/// Indicates that the parser could not decide which of two or more paths
/// to take based upon the remaining input.
///
/// It tracks the starting token of the offending input and also knows where
/// the parser was in the various paths when the error.
class NoViableAltException extends RecognitionException {

  /// Which configurations did we try at input.index that couldn't match
  /// `input.lookToken(1)`?
  final AtnConfigSet deadEndConfigs;

  /// The token object at the start index; the input source might not be
  /// buffering tokens so get a reference to it. (At the time the error
  /// occurred, of course the source needs to keep a buffer all of the tokens
  /// but later we might not have access to those.)
  final Token startToken;

  NoViableAltException(Parser recognizer,
                       {TokenSource inputSource,
                        Token startToken,
                        Token offendingToken,
                        ParserRuleContext context,
                        this.deadEndConfigs})
    : startToken = _getObject(startToken, recognizer.currentToken),
      super(recognizer,
            _getObject(inputSource, recognizer.inputSource),
            _getObject(context, recognizer.context)) {
    this.offendingToken = _getObject(offendingToken, recognizer.currentToken);
  }

  static dynamic _getObject(o1, o2) => o1 != null ? o1 : o2;
}

class LexerNoViableAltException extends RecognitionException {

  /// Matching attempted at what input index?
  final int startIndex;

  /// Which configurations did we try at `input.index` that couldn't match
  /// `input.lookAhead(1)`?
  final AtnConfigSet deadEndConfigs;

  LexerNoViableAltException(Lexer lexer,
                            StringSource input,
                            this.startIndex,
                            this.deadEndConfigs)
      : super(lexer, input, null);


  String toString() {
    String symbol = "";
    if (startIndex >= 0 && startIndex < inputSource.length) {
      var interval = Interval.of(startIndex,startIndex);
      symbol = (inputSource as StringSource).getText(interval);
      symbol = symbol.replaceAll('\t', "\\t");
      symbol = symbol.replaceAll('\n', "\\n");
      symbol = symbol.replaceAll('\r', "\\r");
    }
    return "$LexerNoViableAltException('$symbol')";
  }
}
