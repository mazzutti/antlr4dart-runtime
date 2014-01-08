part of antlr4dart;


/**
 * A semantic predicate failed during validation.  Validation of predicates
 * occurs when normally parsing the alternative just like matching a token.
 * Disambiguating predicate evaluation occurs when we test a predicate during
 * prediction.
 */
class FailedPredicateException extends RecognitionException {
  final int ruleIndex;
  final int predicateIndex;
  final String predicate;

  FailedPredicateException(Parser recognizer,
                           [String predicate,
                           String message])
      : super.withMessage(_formatMessage(predicate, message),
                          recognizer,
                          recognizer.inputSource,
                          recognizer.context),
      ruleIndex = (recognizer.interpreter.atn.states[
          recognizer.state].transition(0) as PredicateTransition).ruleIndex,
      predicateIndex = (recognizer.interpreter.atn.states[
          recognizer.state].transition(0) as PredicateTransition).predIndex,
      predicate = predicate {
    _offendingToken = recognizer.currentToken;
  }


  static String _formatMessage(String predicate, String message) {
    if (message != null) return message;
    return "failed predicate: {$predicate}?";
  }
}
