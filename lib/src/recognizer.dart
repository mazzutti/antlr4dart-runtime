part of antlr4dart;

abstract class Recognizer<T, AtnInterpreter extends AtnSimulator> {

  static const int EOF = -1;

  List<ErrorListener> _listeners;

  static final _tokenTypeMapCache = new HashMap<List<String>, Map<String, int>>();
  static final _ruleIndexMapCache = new HashMap<List<String>, Map<String, int>>();

  AtnInterpreter interpreter;

  /**
   * Indicate that the recognizer has changed internal state that is
   * consistent with the ATN state passed in.  This way we always know
   * where we are in the ATN as the parser goes along. The rule
   * context objects form a stack that lets us see the stack of
   * invoking rules. Combine this and we have complete ATN
   * configuration information.
   */
  int state = -1;

  Recognizer() {
    _listeners = new List<ErrorListener>();
    _listeners.add(ConsoleErrorListener.INSTANCE);
  }

  /**
   * Used to print out token names like ID during debugging and
   * error reporting.  The generated parsers implement a method
   * that overrides this to point to their List<String> tokenNames.
   */
  List<String> get tokenNames;

  List<String> get ruleNames;

  IntSource get inputSource;

  void set inputSource(IntSource input);

  TokenFactory get tokenFactory;

  void set tokenFactory(TokenFactory input);

  /**
   * For debugging and other purposes, might want the grammar name.
   * Have antlr4dart generate an implementation for this method.
   */
  String get grammarFileName;

  Atn get atn;

  List<ErrorListener> get errorListeners => _listeners;

  ErrorListener get errorListenerDispatch {
    return new ProxyErrorListener(errorListeners);
  }

  /**
   * What is the error header, normally line/character position information?
   */
  String getErrorHeader(RecognitionException e) {
    int line = e.offendingToken.line;
    int charPositionInLine = e.offendingToken.charPositionInLine;
    return "line $line:$charPositionInLine";
  }

  /**
   * How should a token be displayed in an error message? The default
   * is to display just the text, but during development you might
   * want to have a lot of information spit out.  Override in that case
   * to use t.toString() (which, for CommonToken, dumps everything about
   * the token). This is better than forcing you to override a method in
   * your token objects because you don't have to go modify your lexer
   * so that it creates a new Java type.
   */
  String getTokenErrorDisplay(Token t) {
    if (t == null) return "<no token>";
    String s = t.text;
    if (s == null) {
      s = (t.type == Token.EOF) ? "<EOF>":"<${t.type}>";
    }
    s = s.replaceAll("\n","\\n");
    s = s.replaceAll("\r","\\r");
    s = s.replaceAll("\t","\\t");
    return "'$s'";
  }

  /**
   * Get a map from token names to token types.
   *
   * Used for tree pattern compilation.
   */
  Map<String, int> get tokenTypeMap {
    if (tokenNames == null) {
      throw new UnsupportedError("The current recognizer does not provide a list of token names.");
    }
    Map<String, int> result = _tokenTypeMapCache[tokenNames];
    if (result == null) {
      Map<String, int> result = new HashMap<String, int>();
      for (int i = 0; i < tokenNames.length; i++) {
        result[tokenNames[i]] = i;
      }
      result["EOF"] = Token.EOF;
      result = new UnmodifiableMapView(result);
      _tokenTypeMapCache[tokenNames] = result;
    }
    return result;
  }

  /**
   * Get a map from rule names to rule indexes.
   *
   * Used for tree pattern compilation.
   */
  Map<String, int> get ruleIndexMap {
    if (ruleNames == null) {
      throw new UnsupportedError("The current recognizer does not provide a list of rule names.");
    }
    Map<String, int> result = _ruleIndexMapCache[ruleNames];
    if (result == null) {
      Map<String, int> m = new HashMap<String, int>();
      for (int i = 0; i < ruleNames.length; i++) {
        m[ruleNames[i]] = i;
      }
      result = new UnmodifiableMapView(m);
      _ruleIndexMapCache[ruleNames] = result;
    }
    return result;
  }

  int getTokenType(String tokenName) {
    int ttype = tokenTypeMap[tokenName];
    if (ttype != null) return ttype;
    return Token.INVALID_TYPE;
  }

  /**
   * If this recognizer was generated, it will have a serialized ATN
   * representation of the grammar.
   *
   * For interpreters, we don't know their serialized ATN despite having
   * created the interpreter from it.
   */
  String get serializedAtn {
    throw new UnsupportedError("there is no serialized ATN");
  }

  /**
   * Throws [NullThrownError] if `listener` is `null`.
   */
  void addErrorListener(ErrorListener listener) {
    if (listener == null) throw new NullThrownError();
    _listeners.add(listener);
  }

  void removeErrorListener(ErrorListener listener) {
    _listeners.remove(listener);
  }

  void removeErrorListeners() {
    _listeners.clear();
  }

  // subclass needs to override these if there are sempreds or actions
  // that the ATN interp needs to execute
  bool sempred(RuleContext _localctx, int ruleIndex, int actionIndex) {
    return true;
  }

  bool precpred(RuleContext localctx, int precedence) {
    return true;
  }

  void action(RuleContext _localctx, int ruleIndex, int actionIndex) {}
}
