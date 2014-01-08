part of antlr4dart;

/**
 * A lexer is recognizer that draws input symbols from a character source.
 * lexer grammars result in a subclass of this object. A Lexer object
 * uses simplified match() and error recovery mechanisms in the interest
 * of speed.
 */
abstract class Lexer extends Recognizer<int, LexerAtnSimulator> implements TokenProvider {
  static const int _DEFAULT_MODE = 0;
  static const int MORE = -2;
  static const int SKIP = -3;

  static const int DEFAULT_TOKEN_CHANNEL = Token.DEFAULT_CHANNEL;
  static const int HIDDEN = Token.HIDDEN_CHANNEL;
  static const int MIN_CHAR_VALUE = 0;
  static const int MAX_CHAR_VALUE = 65534;

  Pair<TokenProvider, CharSource> _tokenFactorySourcePair;
  final List<int> _modeStack = new List<int>();

  // Alias
  int get DEFAULT_MODE => _DEFAULT_MODE;

  // You can set the text for the current token to override what is in
  // the input char buffer.
  String _text;

  /*
   * How to create token objects.
   */
  TokenFactory tokenFactory = CommonTokenFactory.DEFAULT;

  CharSource input;

  /**
   * The goal of all lexer rules/methods is to create a token object.
   * This is an instance variable as multiple rules may collaborate to
   * create a single token.  nextToken will return this object after
   * matching lexer rule(s).  If you subclass to allow multiple token
   * emissions, then set this to the last token to be matched or
   * something nonnull so that the auto token emit mechanism will not
   * emit another token.
   */
  Token token;

  /**
   * What character index in the source did the current token start at?
   * Needed, for example, to get the text for current token.  Set at
   * the start of nextToken.
   */
  int tokenStartCharIndex = -1;

  /**
   * The line on which the first character of the token resides.
   */
  int tokenStartLine;

  /**
   * The character position of first character within the line.
   */
  int tokenStartCharPositionInLine;

  /**
   * Once we see EOF on char source, next token will be EOF.
   * If you have DONE : EOF ; then you see DONE EOF.
   */
  bool hitEof = false;

  /**
   * The channel number for the current token.
   */
  int channel;

  /**
   * The token type for the current token.
   */
  int type;

  int mode = _DEFAULT_MODE;

  Lexer(this.input) {
    _tokenFactorySourcePair = new Pair<TokenProvider, CharSource>(this, input);
  }

  void reset() {
    // wack Lexer state variables
    if (input != null) input.seek(0); // rewind the input
    token = null;
    type = Token.INVALID_TYPE;
    channel = Token.DEFAULT_CHANNEL;
    tokenStartCharIndex = -1;
    tokenStartCharPositionInLine = -1;
    tokenStartLine = -1;
    text = null;
    hitEof = false;
    mode = _DEFAULT_MODE;
    _modeStack.clear();
    interpreter.reset();
  }

  /**
   * Return a token from this source; i.e., match a token on the char source.
   */
  Token nextToken() {
    if (input == null) {
      throw new StateError("nextToken requires a non-null input source.");
    }
    // Mark start location in char source so unbuffered sources are
    // guaranteed at least have text of current token
    int tokenStartMarker = input.mark;
    try{
      outer: while (true) {
        if (hitEof) {
          emitEof();
          return token;
        }
        token = null;
        channel = Token.DEFAULT_CHANNEL;
        tokenStartCharIndex = input.index;
        tokenStartCharPositionInLine = interpreter.charPositionInLine;
        tokenStartLine = interpreter.line;
        text = null;
        do {
          type = Token.INVALID_TYPE;
          int ttype;
          try {
            ttype = interpreter.match(input, mode);
          } on LexerNoViableAltException catch (e) {
            notifyListeners(e);   // report error
            recover(e);
            ttype = SKIP;
          }
          if (input.lookAhead(1) == IntSource.EOF) {
            hitEof = true;
          }
          if (type == Token.INVALID_TYPE) {
            type = ttype;
          }
          if (type == SKIP) continue outer;
        } while (type == MORE);
        if (token == null) emit();
        return token;
      }
    } finally {
      // make sure we release marker after match or
      // unbuffered char source will keep buffering
      input.release(tokenStartMarker);
    }
  }

  /**
   * Instruct the lexer to skip creating a token for current lexer rule
   * and look for another token.  nextToken() knows to keep looking when
   * a lexer rule finishes with token set to SKIP_TOKEN.  Recall that
   * if token == null at end of any token rule, it creates one for you
   * and emits it.
   */
  void skip() {
    type = SKIP;
  }

  void more() {
    type = MORE;
  }

  void pushMode(int m) {
    if (LexerAtnSimulator._debug) print("pushMode $m");
    _modeStack.add(mode);
    mode = m;
  }

  int popMode() {
    if (_modeStack.isEmpty) throw new StateError('');
    if (LexerAtnSimulator._debug) print("popMode back to ${_modeStack.last}");
    mode = _modeStack.removeLast();
    return mode;
  }

  /**
   * Set the char source and reset the lexer.
   */
  void set inputSource(IntSource source) {
    input = null;
    _tokenFactorySourcePair = new Pair<TokenProvider, CharSource>(this, input);
    reset();
    input = source;
    _tokenFactorySourcePair = new Pair<TokenProvider, CharSource>(this, input);
  }

  CharSource get inputSource =>  input;

  String get sourceName => input.sourceName;

  /**
   * By default does not support multiple emits per nextToken invocation
   * for efficiency reasons.  Subclass and override this method, nextToken,
   * and getToken (to push tokens into a list and pull from that list
   * rather than a single variable as this implementation does).
   */
  void emitToken(Token token) {
    this.token = token;
  }

  /**
   * The standard method called to automatically emit a token at the
   * outermost lexical rule.  The token object should point into the
   * char buffer start..stop.  If there is a text override in 'text',
   * use that to set the token's text.  Override this method to emit
   * custom Token objects or provide a new factory.
   */
  Token emit() {
    Token t = tokenFactory(_tokenFactorySourcePair, type, _text, channel,
        tokenStartCharIndex, charIndex - 1, tokenStartLine, tokenStartCharPositionInLine);
    emitToken(t);
    return t;
  }

  Token emitEof() {
    int cpos = charPositionInLine;
    // The character position for EOF is one beyond the position of
    // the previous token's last character
    if (token != null) {
      int n = token.stopIndex - token.startIndex + 1;
      cpos = token.charPositionInLine + n;
    }
    Token eof = tokenFactory(_tokenFactorySourcePair, Token.EOF, null,
        Token.DEFAULT_CHANNEL, input.index, input.index - 1, line, cpos);
    emitToken(eof);
    return eof;
  }

  int get line => interpreter.line;

  int get charPositionInLine => interpreter.charPositionInLine;

  void set line(int line) {
    interpreter.line = line;
  }

  void set charPositionInLine(int charPositionInLine) {
    interpreter.charPositionInLine = charPositionInLine;
  }

  /**
   * What is the index of the current character of lookahead?
   */
  int get charIndex => input.index;

  /**
   * Return the text matched so far for the current token or any
   * text override.
   */
  String get text {
    if (_text != null) return _text;
    return interpreter.getText(input);
  }

  /**
   * Set the complete text of this token; it wipes any previous
   * changes to the text.
   */
  void set text(String text) {
    _text = text;
  }

  List<String> get modeNames => null;

  /**
   * Used to print out token names like ID during debugging and
   * error reporting.  The generated parsers implement a method
   * that overrides this to point to their List<String> tokenNames.
   */
  List<String> get tokenNames => null;

  /**
   * Return a list of all Token objects in input char source.
   * Forces load of all tokens. Does not include EOF token.
   */
  List<Token> get allTokens {
    List<Token> tokens = new List<Token>();
    Token t = nextToken();
    while (t.type != Token.EOF) {
      tokens.add(t);
      t = nextToken();
    }
    return tokens;
  }

  /**
   * Lexers can normally match any char in it's vocabulary after matching
   * a token, so do the easy thing and just kill a character and hope
   * it all works out.  You can instead use the rule invocation stack
   * to do sophisticated error recovery if you are in a fragment rule.
   */
  void recover(dynamic e) {
    if (e is LexerNoViableAltException) {
      if (input.lookAhead(1) != IntSource.EOF) {
        // skip a char and try again
        interpreter.consume(input);
      }
      return;
    } if (e is RecognitionException) {
      input.consume();
    }
  }

  void notifyListeners(LexerNoViableAltException e) {
    String text = input.getText(Interval.of(tokenStartCharIndex, input.index));
    String msg = "token recognition error at: '${getErrorDisplay(text)}'";
    errorListenerDispatch.syntaxError(this, null, tokenStartLine, tokenStartCharPositionInLine, msg, e);
  }

  String getErrorDisplay(String s) {
    return getScapedErrorDisplay(s);
  }

  String getScapedErrorDisplay(String s) {
    s = s.replaceAll('\n', '\\n');
    s = s.replaceAll('\t', '\\t');
    return s.replaceAll('\r', '\\r');
  }

  String getCharErrorDisplay(String c) => "'$c'";
}
