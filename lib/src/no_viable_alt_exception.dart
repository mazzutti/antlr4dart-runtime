part of antlr4dart;

/**
 * Indicates that the parser could not decide which of two or more paths
 * to take based upon the remaining input. It tracks the starting token
 * of the offending input and also knows where the parser was
 * in the various paths when the error. Reported by reportNoViableAlternative()
 */
class NoViableAltException extends RecognitionException {
  /**
   * Which configurations did we try at input.index that couldn't match input.lookToken(1)?
   */
  final AtnConfigSet deadEndConfigs;

  /**
   * The token object at the start index; the input source might
   * not be buffering tokens so get a reference to it. (At the
   * time the error occurred, of course the source needs to keep a
   * buffer all of the tokens but later we might not have access to those.)
   */
  final Token startToken;

  NoViableAltException.recog(Parser recognizer)
    : this(recognizer,
           recognizer.inputSource,
           recognizer.currentToken,
           recognizer.currentToken,
           null,
           recognizer.context);

  NoViableAltException(Parser recognizer,
                       TokenSource input,
                       this.startToken,
                       Token offendingToken,
                       this.deadEndConfigs,
                       ParserRuleContext ctx)
    : super(recognizer, input, ctx) {
    _offendingToken = offendingToken;
  }
}
