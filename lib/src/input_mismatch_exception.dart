part of antlr4dart;

/**
 * This signifies any kind of mismatched input exceptions such as
 * when the current input does not match the expected token.
 */
class InputMismatchException extends RecognitionException {
  InputMismatchException(Parser recognizer)
      : super(recognizer, recognizer.inputSource, recognizer.context) {
    _offendingToken = recognizer.currentToken;
  }
}
