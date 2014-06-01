part of antlr4dart;

/// Buffer all input tokens but do on-demand fetching of new tokens from lexer.
/// Useful when the parser or lexer has to set context/mode info before proper
/// lexing of future tokens. The ST template parser needs this, for example,
/// because it has to constantly flip back and forth between inside/output
/// templates. E.g., `<names:{hi, <it>}>` has to parse names as part of an
/// expression but `"hi, <it>"` as a nested template.
///
/// You can't use this source if you pass whitespace or other off-channel tokens
/// to the parser. The source can't ignore off-channel tokens.
/// ([UnbufferedTokenSource] is the same way.) Use [CommonTokenSource].
class BufferedTokenSource implements TokenSource {
  TokenProvider _tokenProvider;

  // Record every single token pulled from the source so we can reproduce
  // chunks of it later. This list captures everything so we can access
  // complete input text.
  List<Token> _tokens = new List<Token>();

  // The index into tokens of the current token (next token to
  // consume). tokens[_p] should be lookToken(1). _p =- 1 indicates
  // need to initialize with first token. The constructor doesn't get
  // a token. First call to lookToken(1) or whatever gets the first token
  // and sets _p = 0;.
  int _p = -1;

  // Set to true when the EOF token is fetched. Do not continue fetching
  // tokens after that point, or multiple EOF tokens could end up in the
  // tokens list.
  bool _fetchedEof = false;

  BufferedTokenSource(TokenProvider tokenProvider) {
    if (tokenProvider == null) throw new NullThrownError();
    _tokenProvider = tokenProvider;
  }

  TokenProvider get tokenProvider => _tokenProvider;

  int get index => _p;

  int get mark => 0;

  int get length => _tokens.length;

  List<Token> get tokens => _tokens;

  String get sourceName => _tokenProvider.sourceName;

  /// Get the text of all tokens in this buffer.
  String get text {
    _lazyInit();
    fill();
    return getTextIn(Interval.of(0, length - 1));
  }

  /// Reset this token source by setting its token source.
  void set tokenProvider(TokenProvider tokenProvider) {
    _tokenProvider = tokenProvider;
    _tokens.clear();
    _p = -1;
  }

  String getTextIn(Interval interval) {
    int start = interval.a;
    int stop = interval.b;
    if (start < 0 || stop < 0) return "";
    _lazyInit();
    if (stop >= _tokens.length) stop = _tokens.length - 1;
    StringBuffer buf = new StringBuffer();
    for (int i = start; i <= stop; i++) {
      Token t = _tokens[i];
      if (t.type == Token.EOF) break;
      buf.write(t.text);
    }
    return buf.toString();
  }

  String getText(Token start, Token stop) {
    if (start != null && stop != null) {
      return getTextIn(Interval.of(start.tokenIndex, stop.tokenIndex));
    }
    return "";
  }

  /// Get all tokens from lexer until EOF.
  void fill() {
    _lazyInit();
    int blockSize = 1000;
    while (true) {
      int fetched = _fetch(blockSize);
      if (fetched < blockSize) {
        return;
      }
    }
  }

  /// Given a start and stop index, return a List of all tokens in
  /// the token type BitSet.  Return null if no tokens were found.  This
  /// method looks at both on and off channel tokens.
  List<Token> getTokens(int start, int stop, [Set<int> types]) {
    _lazyInit();
    if (start < 0 || stop >= _tokens.length || stop < 0 || start >= _tokens.length) {
      throw new RangeError("start $start or stop $stop not in 0..${_tokens.length - 1}");
    }
    if (start > stop) return null;
    List<Token> filteredTokens = new List<Token>();
    for (int i = start; i <= stop; i++) {
      Token t = _tokens[i];
      if (types == null || types.contains(t.type)) {
        filteredTokens.add(t);
      }
    }
    if (filteredTokens.isEmpty) {
      filteredTokens = null;
    }
    return filteredTokens;
  }

  void release(int marker) {}

  void reset() {
    seek(0);
  }

  void seek(int index) {
    _lazyInit();
    _p = adjustSeekIndex(index);
  }

  void consume() {
    bool skipEofCheck;
    if (_p >= 0) {
      if (_fetchedEof) {
        // the last token in tokens is EOF. skip check if p indexes any
        // fetched token except the last.
        skipEofCheck = _p < tokens.length - 1;
      } else {
        // no EOF token in tokens. skip check if p indexes a fetched token.
        skipEofCheck = _p < tokens.length;
      }
    } else {
      // not yet initialized
      skipEofCheck = false;
    }
    if (!skipEofCheck && lookAhead(1) == IntSource.EOF) {
      throw new StateError("cannot consume EOF");
    }
    if (_sync(_p + 1)) {
      _p = adjustSeekIndex(_p + 1);
    }
  }

  Token get(int i) {
    if (i < 0 || i >= _tokens.length) {
      throw new RangeError(
          "token index $i out of range 0..${_tokens.length - 1}");
    }
    return _tokens[i];
  }

  /// Get all tokens from start..stop inclusively
  List<Token> getRange(int start, int stop) {
    if (start < 0 || stop < 0) return null;
    _lazyInit();
    List<Token> subset = new List<Token>();
    if (stop >= _tokens.length) stop = _tokens.length - 1;
    for (int i = start; i <= stop; i++) {
      Token t = _tokens[i];
      if (t.type == Token.EOF) break;
      subset.add(t);
    }
    return subset;
  }

  int lookAhead(int i) => lookToken(i).type;

  Token lookToken(int k) {
    _lazyInit();
    if (k == 0) return null;
    if (k < 0) return _lookBack(-k);
    int i = _p + k - 1;
    _sync(i);
    if (i >= _tokens.length) { // return EOF token
      // EOF must be last token
      return _tokens.last;
    }
    return _tokens[i];
  }

  /// Collect all tokens on specified channel to the right of
  /// the current token up until we see a token on DEFAULT_TOKEN_CHANNEL or
  /// EOF. If channel is -1, find any non default channel token.
  List<Token> getHiddenTokensToRight(int tokenIndex, [int channel = -1]) {
    _lazyInit();
    if ( tokenIndex<0 || tokenIndex >= _tokens.length) {
      throw new RangeError("$tokenIndex not in 0..${_tokens.length - 1}");
    }
    int nextOnChannel = _nextTokenOnChannel(tokenIndex + 1, Lexer.DEFAULT_TOKEN_CHANNEL);
    int to;
    int from = tokenIndex+1;
    // if none onchannel to right, nextOnChannel=-1 so set to = last token
    if (nextOnChannel == -1) to = length - 1;
    else to = nextOnChannel;
    return _filterForChannel(from, to, channel);
  }

  /// Collect all tokens on specified channel to the left of
  /// the current token up until we see a token on DEFAULT_TOKEN_CHANNEL.
  /// If channel is -1, find any non default channel token.
  List<Token> getHiddenTokensToLeft(int tokenIndex, [int channel = -1]) {
    _lazyInit();
    if (tokenIndex < 0 || tokenIndex >= _tokens.length) {
      throw new RangeError("$tokenIndex not in 0..${_tokens.length - 1}");
    }
    int prevOnChannel = _previousTokenOnChannel(tokenIndex - 1, Lexer.DEFAULT_TOKEN_CHANNEL);
    if (prevOnChannel == tokenIndex - 1) return null;
    // if none onchannel to left, prevOnChannel=-1 then from=0
    int from = prevOnChannel + 1;
    int to = tokenIndex-1;
    return _filterForChannel(from, to, channel);
  }

  /// Allowed derived classes to modify the behavior of operations which change
  /// the current source position by adjusting the target token index of a seek
  /// operation. The default implementation simply returns i. If an
  /// exception is thrown in this method, the current source index should not be
  /// changed.
  ///
  /// For example, CommonTokenSource overrides this method to ensure that
  /// the seek target is always an on-channel token.
  ///
  /// [i] is the target token index.
  /// Return the adjusted target token index.
  int adjustSeekIndex(int i) => i;

  // Make sure index i in _tokens has a token.
  // Return true if a token is located at index i, otherwise false.
  bool _sync(int i) {
    assert(i >= 0);
    int n = i - _tokens.length + 1; // how many more elements we need?
    if (n > 0) {
      int fetched = _fetch(n);
      return fetched >= n;
    }
    return true;
  }

  // Add n elements to buffer.
  // Return the actual number of elements added to the buffer.
  int _fetch(int n) {
    if (_fetchedEof) return 0;
    for (int i = 0; i < n; i++) {
      Token t = _tokenProvider.nextToken();
      if (t is WritableToken) {
        t.tokenIndex = _tokens.length;
      }
      _tokens.add(t);
      if (t.type == Token.EOF) {
        _fetchedEof = true;
        return i + 1;
      }
    }
    return n;
  }

  Token _lookBack(int k) {
    if ((_p - k) < 0) return null;
    return _tokens[_p - k];
  }

  void _lazyInit() {
    if (_p == -1) {
      _sync(0);
      _p = adjustSeekIndex(0);
    }
  }

  // Given a starting index, return the index of the next token on channel.
  // Return i if _tokens[i] is on channel.  Return -1 if there are no tokens
  // on channel between i and EOF.
  int _nextTokenOnChannel(int i, int channel) {
    _sync(i);
    Token token = _tokens[i];
    if (i >= length) return -1;
    while (token.channel != channel) {
      if (token.type == Token.EOF) return -1;
      i++;
      _sync(i);
      token = _tokens[i];
    }
    return i;
  }

  // Given a starting index, return the index of the previous token on channel.
  // Return i if _tokens[i] is on channel. Return -1 if there are no tokens
  // on channel between i and 0.
  int _previousTokenOnChannel(int i, int channel) {
    while (i >= 0 && _tokens[i].channel != channel) i--;
    return i;
  }

  List<Token> _filterForChannel(int from, int to, int channel) {
    List<Token> hidden = new List<Token>();
    for (int i = from; i <= to; i++) {
      Token t = _tokens[i];
      if (channel == -1) {
        if (t.channel != Lexer.DEFAULT_TOKEN_CHANNEL ) hidden.add(t);
      } else {
        if (t.channel == channel) hidden.add(t);
      }
    }
    if (hidden.length == 0) return null;
    return hidden;
  }
}
