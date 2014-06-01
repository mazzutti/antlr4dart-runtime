part of antlr4dart;

/// A semantic predicate failed during validation.  Validation of predicates
/// occurs when normally parsing the alternative just like matching a token.
/// Disambiguating predicate evaluation occurs when we test a predicate during
/// prediction.
class FailedPredicateException extends RecognitionException {
  int _ruleIndex;
  int _predicateIndex;
  final String predicate;

  FailedPredicateException(Parser recognizer,
                           [String predicate,
                           String message])
      : super.withMessage(_formatMessage(predicate, message),
                          recognizer,
                          recognizer.inputSource,
                          recognizer.context),
      predicate = predicate {
    AtnState s = recognizer.interpreter.atn.states[recognizer.state];
    AbstractPredicateTransition trans = s.transition(0);
    if (trans is PredicateTransition) {
      _ruleIndex = trans.ruleIndex;
      _predicateIndex = trans.predIndex;
    } else {
      _ruleIndex = 0;
      _predicateIndex = 0;
    }
    offendingToken = recognizer.currentToken;
  }

  int get ruleIndex => _ruleIndex;

  int get predicateIndex => _predicateIndex;

  static String _formatMessage(String predicate, String message) {
    if (message != null) return message;
    return "failed predicate: {$predicate}?";
  }
}
