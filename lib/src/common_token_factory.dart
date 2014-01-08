part of antlr4dart;

class CommonTokenFactory {

  static final TokenFactory<CommonToken> DEFAULT = new CommonTokenFactory();

  // Copy text for token out of input char source. Useful when input
  // source is unbuffered.
  final bool _copyText;

  /**
   * Create factory and indicate whether or not the factory copy
   * text out of the char source.
   */
  CommonTokenFactory([this._copyText = false]);

  CommonToken call(Pair<TokenProvider, CharSource> source,
                   int type,
                   String text,
                   int channel,
                   int start,
                   int stop,
                   int line,
                   int charPositionInLine) {
    CommonToken t = new CommonToken(source, type, channel, start, stop);
    t.line = line;
    t.charPositionInLine = charPositionInLine;
    if (text != null) {
      t.text = text;
    } else if (_copyText && source.b != null) {
      t.text = source.b.getText(Interval.of(start, stop));
    }
    return t;
  }

}
