part of antlr4dart;

/**
 * Some breaking changes in version 0.7 - changed interface from using
 * [ErrorListener]s to [Stream]s. Events can now be listened to with greater
 * specificity, and more appropriately named. The following [Stream]s can now
 * be listened to:
 *   [Stream]<[SyntaxError]>[onSyntaxError],
 *   [Stream]<[AmbiguityEvent]>[onAmbiguity],
 *   [Stream]<[AttemptingFullContextEvent]>[onAttemptingFullContext], and
 *   [Stream]<[ContextSensitivityEvent]>[onContextSensitivity].
 *   
 * 
 * To fix broken code:
 * 
 * Old broken code:
 *     recognizer.addErrorListener(errorListener);
 *     // do stuff;
 *     recognizer.removeErrorListener(errorListener);
 * 
 * Fix:
 *     var subscription = recognizer.onSyntaxError.listen((e)
 *         => doSomethingWith(e));
 *     // do stuff;
 *     subscription.cancel();
 * 
 * Note if errorListener in the above code block has non-trivial implementations
 * of other functions e.g. reportContextSensitivity, these will have to be
 * subscribed to separately.
 * 
 * Alternatively, you may extend Recognizer with [DeprecatedRecognizerMixin] 
 * from antlr4dart._deprecation_fix.dart for an immediate fix. This isn't
 * advised, as it uses deprecated features that will be removed in future, but
 * may be a sufficient quick-fix for projects with a large code-base solution.
 * 
 * Also note as of version 0.7, syntaxerrors are no longer automatically
 * [print]ed - you must subscribe if this is what you want:
 *     recognizer.onSyntaxError.listen(print);
 */
abstract class Recognizer<T, AtnInterpreter extends AtnSimulator>{
    
  /**
   * [ErrorStrategy] determines how errors are  handled - this is purely an
   * informative [Stream]. Some or all errors may be successfully handled by
   * the [ErrorStrategy] yet still be sent to this [Stream].
   */
  Stream<SyntaxError> get onSyntaxError;

  static final _tokenTypeMapCache = new HashMap();
  static final _ruleIndexMapCache = new HashMap();

  AtnInterpreter interpreter;

  /// Indicate that the recognizer has changed internal state that is
  /// consistent with the ATN state passed in. This way we always know
  /// where we are in the ATN as the parser goes along. The rule context
  /// objects form a stack that lets us see the stack of invoking rules.
  /// Combine this and we have complete ATN configuration information.
  int state = -1; 
  
  Recognizer();
  

  /// Used to print out token names like ID during debugging and
  /// error reporting.  The generated parsers implement a method
  /// that overrides this to point to their List<String> tokenNames.
  List<String> get tokenNames;

  List<String> get ruleNames;

  InputSource get inputSource;

  void set inputSource(InputSource input);

  TokenFactory get tokenFactory;

  void set tokenFactory(TokenFactory input);

  /// For debugging and other purposes, might want the grammar name.
  /// Have antlr4dart generate an implementation for this method.
  String get grammarFileName;

  Atn get atn;

  /// Get a map from token names to token types.
  ///
  /// Used for tree pattern compilation.
  Map<String, int> get tokenTypeMap {
    if (tokenNames == null) {
      throw new UnsupportedError(
          "The current recognizer does not provide a list of token names.");
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

  /// Get a map from rule names to rule indexes.
  ///
  /// Used for tree pattern compilation.
  Map<String, int> get ruleIndexMap {
    if (ruleNames == null) {
      throw new UnsupportedError(
          "The current recognizer does not provide a list of rule names.");
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

  /// What is the error header, normally line/character position information?
  String getErrorHeader(RecognitionException exception) {
    int line = exception.offendingToken.line;
    int charPositionInLine = exception.offendingToken.charPositionInLine;
    return "line $line:$charPositionInLine";
  }

  /// How should a token be displayed in an error message?
  ///
  /// The default is to display just the text, but during development you might
  /// want to have a lot of information spit out. Override in that case
  /// to use [token].toString() (which, for [CommonToken], dumps everything
  /// about the token). This is better than forcing you to override a method in
  /// your token objects because you don't have to go modify your lexer
  /// so that it creates a new Dart type.
  String getTokenErrorDisplay(Token token) {
    if (token == null) return "<no token>";
    String s = token.text;
    if (s == null) {
      s = (token.type == Token.EOF) ? "<EOF>":"<${token.type}>";
    }
    s = s.replaceAll("\n","\\n");
    s = s.replaceAll("\r","\\r");
    s = s.replaceAll("\t","\\t");
    return "'$s'";
  }

  int getTokenType(String tokenName) {
    int ttype = tokenTypeMap[tokenName];
    return ttype != null ? ttype : Token.INVALID_TYPE;
  }

  /// If this recognizer was generated, it will have a serialized ATN
  /// representation of the grammar.
  ///
  /// For interpreters, we don't know their serialized ATN despite having
  /// created the interpreter from it.
  String get serializedAtn {
    throw new UnsupportedError("there is no serialized ATN");
  }

  /// Subclass needs to override these if there are sempreds or actions that
  /// the ATN interpreter needs to execute.
  bool semanticPredicate(RuleContext localContext,
                         int ruleIndex,
                         int actionIndex) => true;

  bool precedencePredicate(RuleContext localContext, int precedence) => true;

  void action(RuleContext localContext, int ruleIndex, int actionIndex) {}
}
