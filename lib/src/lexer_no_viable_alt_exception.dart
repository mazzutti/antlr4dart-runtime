part of antlr4dart;

class LexerNoViableAltException extends RecognitionException {

  /**
   * Matching attempted at what input index?
   */
  final int startIndex;

  /**
   * Which configurations did we try at input.index() that
   * couldn't match input.LA(1)?
   */
  final AtnConfigSet deadEndConfigs;

  LexerNoViableAltException(Lexer lexer,
                            CharSource input,
                            this.startIndex,
                            this.deadEndConfigs)
      : super(lexer, input, null);


  String toString() {
    String symbol = "";
    if (startIndex >= 0 && startIndex < inputSource.length) {
      symbol = (inputSource as CharSource).getText(Interval.of(startIndex,startIndex));
      symbol = symbol.replaceAll('\t', "\\t");
      symbol = symbol.replaceAll('\n', "\\n");
      symbol = symbol.replaceAll('\r', "\\r");
    }
    return "$LexerNoViableAltException('$symbol')";
  }
}
