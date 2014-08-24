part of antlr4dart;

/// An [InputSource] whose symbols are [Token] instances.
abstract class TokenSource extends InputSource {

  /// The underlying [TokenProvider] which provides tokens for this source.
  TokenProvider get tokenProvider;

  /// The text of all tokens in the source.
  ///
  /// This getter behaves like the following code, including potential
  /// exceptions from the calls to [InputSource.length] and [getTextIn],
  /// but may be optimized by the specific implementation.
  ///
  ///      TokenSource source = ...;
  ///      String text = source.getTextIn(new Interval(0, source.length));
  String get text;

  /// Get the [Token] instance associated with the value returned by
  /// `lookAhead(k)`. This method has the same pre- and post-conditions as
  /// [InputSource.lookAhead]. In addition, when the preconditions of this
  /// method are met, the return value is non-null and the value of
  /// `lookToken(k).type == lookAhead(k)`.
  Token lookToken(int k);

  /// Gets the [Token] at the specified `index` in the source. When
  /// the preconditions of this method are met, the return value is non-null.
  ///
  /// The preconditions for this method are the same as the preconditions of
  /// [InputSource.seek]. If the behavior of `seek(index)` is unspecified for
  /// the current state and given [index], then the behavior of this method
  /// is also unspecified.
  ///
  /// The symbol referred to by [index] differs from [seek] only in the case
  /// of filtering sources where [index] lies before the end of the source.
  /// Unlike [seek], this method does not adjust [index] to point to a
  /// non-ignored symbol.
  ///
  /// An [ArgumentError] occurs when if [index] is less than 0.
  /// An [UnsupportedError] occurs when the source does not support
  /// retrieving the token at the specified index
  Token get(int index);

  /// Return the text of all tokens within the specified [interval].
  ///
  /// This method behaves like the following code (including potential
  /// exceptions for violating preconditions of [get], but may be optimized
  /// by the specific implementation.
  ///
  ///      TokenSource source = ...;
  ///      String text = "";
  ///      for (int i = interval.a; i <= interval.b; i++) {
  ///        text += source.get(i).text;
  ///      }
  ///
  /// [interval] is the interval of tokens within this source to get text
  /// for.
  ///
  /// Return The text of all tokens within the specified interval in this
  /// source.
  ///
  /// An [NullThrownError] occurs when [interval] is `null`.
  String getTextIn(Interval interval);

  /// Return the text of all tokens in this source between [start] and
  /// [stop] [Token] (inclusive).
  ///
  /// If the specified [start] or [stop] token was not provided by this source,
  /// or if the [stop] occurred before the [start] token, the behavior is
  /// unspecified.
  ///
  /// For sources which ensure that the [Token.tokenIndex] getter is
  /// accurate for all of its provided tokens, this method behaves like the
  /// following code. Other sources may implement this method in other ways
  /// provided the behavior is consistent with this at a high level.
  ///
  ///      TokenSource source = ...;
  ///      String text = "";
  ///      for (int i = start.tokenIndex; i <= stop.tokenIndex; i++) {
  ///        text += source.get(i).text;
  ///      }
  ///
  /// [start] is the first token in the interval to get text for.
  /// [stop] is the last token in the interval to get text for (inclusive).
  ///
  /// Return the text of all tokens lying between the specified [start]
  /// and [stop] tokens.
  ///
  /// An [UnsupportedError] occurs when this source does not support this
  /// method for the specified tokens.
  String getText(Token start, Token stop);
}

/// Buffer all input tokens but do on-demand fetching of new tokens from lexer.
/// Useful when the parser or lexer has to set context/mode info before proper
/// lexing of future tokens. The ST template parser needs this, for example,
/// because it has to constantly flip back and forth between inside/output
/// templates. E.g., `<names:{hi, <it>}>` has to parse names as part of an
/// expression but `"hi, <it>"` as a nested template.
class BufferedTokenSource implements TokenSource {

  TokenProvider _tokenProvider;

  // Record every single token pulled from the source so we can reproduce
  // chunks of it later. This list captures everything so we can access
  // complete input text.
  List<Token> _tokens = new List<Token>();

  // The index into tokens of the current token (next token to
  // consume). tokens[_index] should be lookToken(1). _index =- 1 indicates
  // need to initialize with first token. The constructor doesn't get
  // a token. First call to lookToken(1) or whatever gets the first token
  // and sets _index = 0;.
  int _index = -1;

  // Set to true when the EOF token is fetched. Do not continue fetching
  // tokens after that point, or multiple EOF tokens could end up in the
  // tokens list.
  bool _fetchedEof = false;

  BufferedTokenSource(TokenProvider tokenProvider) {
    if (tokenProvider == null) throw new NullThrownError();
    _tokenProvider = tokenProvider;
  }

  TokenProvider get tokenProvider => _tokenProvider;

  int get index => _index;

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
    _index = -1;
  }

  String getTextIn(Interval interval) {
    int start = interval._a;
    int stop = interval._b;
    if (start < 0 || stop < 0) return "";
    _lazyInit();
    if (stop >= _tokens.length) stop = _tokens.length - 1;
    StringBuffer sb = new StringBuffer();
    for (int i = start; i <= stop; i++) {
      Token t = _tokens[i];
      if (t.type == Token.EOF) break;
      sb.write(t.text);
    }
    return sb.toString();
  }

  String getText(Token start, Token stop) {
    return (start != null && stop != null)
        ? getTextIn(Interval.of(start.tokenIndex, stop.tokenIndex)) : "";
  }

  /// Get all tokens from lexer until EOF.
  void fill() {
    _lazyInit();
    int blockSize = 1000;
    while (true) {
      int fetched = _fetch(blockSize);
      if (fetched < blockSize) return;
    }
  }

  /// Given a start and stop index, return a List of all tokens in the token
  /// type [BitSet].  Return null if no tokens were found.
  ///
  /// This method looks at both on and off channel tokens.
  List<Token> getTokens(int start, int stop, [Set<int> types]) {
    _lazyInit();
    if (start < 0
        || stop >= _tokens.length
        || stop < 0
        || start >= _tokens.length) {
      throw new RangeError(
          "start $start or stop $stop not in 0..${_tokens.length - 1}");
    }
    if (start > stop) return null;
    List<Token> filteredTokens = new List<Token>();
    for (int i = start; i <= stop; i++) {
      Token token = _tokens[i];
      if (types == null || types.contains(token.type)) {
        filteredTokens.add(token);
      }
    }
    if (filteredTokens.isEmpty) filteredTokens = null;
    return filteredTokens;
  }

  void release(int marker) {}

  void reset() {
    seek(0);
  }

  void seek(int index) {
    _lazyInit();
    _index = adjustSeekIndex(index);
  }

  void consume() {
    bool skipEofCheck;
    if (_index >= 0) {
      if (_fetchedEof) {
        // the last token in tokens is EOF. skip check if p indexes any
        // fetched token except the last.
        skipEofCheck = _index < tokens.length - 1;
      } else {
        // no EOF token in tokens. skip check if p indexes a fetched token.
        skipEofCheck = _index < tokens.length;
      }
    } else {
      // not yet initialized
      skipEofCheck = false;
    }
    if (!skipEofCheck && lookAhead(1) == Token.EOF) {
      throw new StateError("cannot consume EOF");
    }
    if (_sync(_index + 1)) {
      _index = adjustSeekIndex(_index + 1);
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
    int i = _index + k - 1;
    _sync(i);
    // EOF must be last token
    if (i >= _tokens.length) return _tokens.last;
    return _tokens[i];
  }

  /// Collect all tokens on specified channel to the right of the current token
  /// up until we see a token on `DEFAULT_TOKEN_CHANNEL` or `EOF`. If channel
  /// is `-1`, find any non default channel token.
  List<Token> getHiddenTokensToRight(int tokenIndex, [int channel = -1]) {
    _lazyInit();
    if ( tokenIndex<0 || tokenIndex >= _tokens.length) {
      throw new RangeError("$tokenIndex not in 0..${_tokens.length - 1}");
    }
    int nextOnChannel = _nextTokenOnChannel(
        tokenIndex + 1, Token.DEFAULT_CHANNEL);
    int to;
    int from = tokenIndex+1;
    // if none onchannel to right, nextOnChannel=-1 so set to = last token
    if (nextOnChannel == -1) {
      to = length - 1;
    } else {
      to = nextOnChannel;
    }
    return _filterForChannel(from, to, channel);
  }

  /// Collect all tokens on specified channel to the left of the current token
  /// up until we see a token on `DEFAULT_TOKEN_CHANNEL`. If channel is `-1`,
  /// find any non default channel token.
  List<Token> getHiddenTokensToLeft(int tokenIndex, [int channel = -1]) {
    _lazyInit();
    if (tokenIndex < 0 || tokenIndex >= _tokens.length) {
      throw new RangeError("$tokenIndex not in 0..${_tokens.length - 1}");
    }
    // obviously no tokens can appear before the first token
    if (tokenIndex == 0) return null;
    int prevOnChannel = _previousTokenOnChannel(
        tokenIndex - 1, Token.DEFAULT_CHANNEL);
    if (prevOnChannel == tokenIndex - 1) return null;
    // if none onchannel to left, prevOnChannel=-1 then from=0
    int from = prevOnChannel + 1;
    int to = tokenIndex-1;
    return _filterForChannel(from, to, channel);
  }

  /// Allowed derived classes to modify the behavior of operations which change
  /// the current source position by adjusting the target token index of a seek
  /// operation. The default implementation simply returns i. If an exception
  /// is thrown in this method, the current source index should not be changed.
  ///
  /// For example, [CommonTokenSource] overrides this method to ensure that
  /// the seek target is always an on-channel token.
  ///
  /// [i] is the target token index.
  ///
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
      Token token = _tokenProvider.nextToken();
      if (token is WritableToken) {
        token.tokenIndex = _tokens.length;
      }
      _tokens.add(token);
      if (token.type == Token.EOF) {
        _fetchedEof = true;
        return i + 1;
      }
    }
    return n;
  }

  Token _lookBack(int k) => (_index - k) < 0 ? null : _tokens[_index - k];

  void _lazyInit() {
    if (_index == -1) {
      _sync(0);
      _index = adjustSeekIndex(0);
    }
  }

  // Given a starting index, return the index of the next token on channel.
  // Return i if _tokens[i] is on channel. Return -1 if there are no tokens
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

  // Given a starting index, return the index of the previous token on
  // channel. Return i if tokens[i] is on channel. Return -1 if there are
  // no tokens on channel between i and 0.
  //
  // If i specifies an index at or after the EOF token, the EOF token
  // index is returned. This is due to the fact that the EOF token is treated
  // as though it were on every channel.
  int _previousTokenOnChannel(int i, int channel) {
    _sync(i);
    // the EOF token is on every channel
    if (i >= length) return length - 1;
    while (i >= 0) {
      Token token = tokens[i];
      if (token.type == Token.EOF || token.channel == channel) return i;
      i--;
    }
    return i;
  }

  List<Token> _filterForChannel(int from, int to, int channel) {
    List<Token> hidden = new List<Token>();
    for (int i = from; i <= to; i++) {
      Token t = _tokens[i];
      if (channel == -1) {
        if (t.channel != Token.DEFAULT_CHANNEL) hidden.add(t);
      } else {
        if (t.channel == channel) hidden.add(t);
      }
    }
    if (hidden.length == 0) return null;
    return hidden;
  }
}

/// The most common source of tokens where every token is buffered up
/// and tokens are filtered for a certain channel (the parser will only
/// see these tokens).
///
/// Even though it buffers all of the tokens, this token source pulls tokens
/// from the tokens source on demand. In other words, until you ask for a
/// token using [consume], [lookToken], etc. the source does not pull from
/// the lexer.
///
/// The only difference between this source and [BufferedTokenSource] superclass
/// is that this source knows how to ignore off channel tokens. There may be
/// a performance advantage to using the superclass if you don't pass
/// whitespace and comments etc. to the parser on a hidden channel (i.e.,
/// you set `channel` instead of calling [Lexer.skip] in lexer rules.)
class CommonTokenSource extends BufferedTokenSource {

  // Skip tokens on any channel but this one; this is how we skip whitespace...
  int _channel;

  CommonTokenSource(TokenProvider tokenProvider,
                    [this._channel = Token.DEFAULT_CHANNEL])
      : super(tokenProvider);

  /// Count EOF just once.
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
    int i = _index;
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
    if (k == 0 || (_index - k) < 0) return null;
    int i = _index;
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

