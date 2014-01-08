part of antlr4dart;

/**
 * The most common source of tokens where every token is buffered up
 * and tokens are filtered for a certain channel (the parser will only
 * see these tokens).
 *
 * Even though it buffers all of the tokens, this token source pulls tokens
 * from the tokens source on demand. In other words, until you ask for a
 * token using consume(), lookToken(), etc. the source does not pull from the lexer.
 *
 * The only difference between this source and [BufferedTokenSource] superclass
 * is that this source knows how to ignore off channel tokens. There may be
 * a performance advantage to using the superclass if you don't pass
 * whitespace and comments etc. to the parser on a hidden channel (i.e.,
 * you set `channel` instead of calling `skip()` in lexer rules.)
 */
class CommonTokenSource extends BufferedTokenSource {

  // Skip tokens on any channel but this one; this is how we skip whitespace...
  int _channel;

  CommonTokenSource(TokenProvider tokenProvider,
                    [this._channel = Token.DEFAULT_CHANNEL]) : super(tokenProvider);

  /**
   * Count EOF just once.
   */
  int get numberOfOnChannelTokens {
    int n = 0;
    fill();
    for (int i = 0; i < _tokens.length; i++) {
      Token t = _tokens[i];
      if (t.channel == _channel) n++;
      if (t.type == Token.EOF) break;
    }
    return n;
  }

  int adjustSeekIndex(int i) {
    return _nextTokenOnChannel(i, _channel);
  }

  Token lookToken(int k) {
    _lazyInit();
    if (k == 0) return null;
    if (k < 0) return _lookBack(-k);
    int i = _p;
    int n = 1; // we know tokens[p] is a good one
    // find k good tokens
    while (n < k) {
      // skip off-channel tokens, but make sure to not look past EOF
      if (_sync(i + 1)) {
        i = _nextTokenOnChannel(i + 1, _channel);
      }
      n++;
    }
    return _tokens[i];
  }

  Token _lookBack(int k) {
    if (k == 0 || (_p - k) < 0) return null;
    int i = _p;
    int n = 1;
    // find k good tokens looking backwards
    while (n <= k) {
      // skip off-channel tokens
      i = _previousTokenOnChannel(i - 1, _channel);
      n++;
    }
    if (i < 0) return null;
    return _tokens[i];
  }
}
