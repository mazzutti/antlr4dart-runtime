part of antlr4dart.deprecation_fix;
/**
 * Mixin for back-compatibility of [Parser] with deprecation of [ErrorListener].
 * 
 * Functions very similarly to [DeprecatedParserMixin] except forwards
 * additional parser-specific events. If you are fixing a parser, use this. If
 * you are fixing a non-parser recognizer (e.g. lexer) user
 * [DeprecatedRecognizerMixin]. Do not use both.
 * 
 * Usage: while users are encouraged to re-write code using [ErrorListener]s
 * with the [Stream]-based interface around [Parser].on*, this mixin class
 * allows old recognizers to work almost immediately.
 * 
 * [deprecatedMixinInit] must be called before back-compatibility
 * works as expected.
 * 
 * Old broken code
 *     class MyLanguageSpecificParser extends Parser{
 *       MyLanguageSpecificParser();
 *       
 *       //stuff involving funcitons removed from the Parser API
 *       //throw NoSuchMethodErrors
 *     }
 * 
 * New code
 *     class MyLanguageSpecificParser extends Parser with DeprecatedParserMixin{
 *       MyLanguageSpecificParser(){
 *         deprecatedParserMixinInit();
 *         //functions removed from the old Parser API now work as expected.
 *       }
 * 
 *       //stuff involving functions removed from the old Parser API execute!
 *     }
 */
abstract class DeprecatedParserMixin implements DeprecatedRecognizerMixin, Parser{
  List<ErrorListener> _listeners = new List<ErrorListener>();
  
  /**
   * Must be called after parser creation in order for deprecation fixes
   * to work.
   */
  void deprecatedMixinInit({bool autoAddConsoleErrorListener: true}){
    if (autoAddConsoleErrorListener){
      _listeners.add(ConsoleErrorListener.INSTANCE);
    }
    //temporary fix.
    _subscribeListeners();
  }
  
  @override
  Stream<ParserSyntaxError> get onSyntaxError;
  
  /**
   * Sets up subscriptions to [errorListener]s. Since the forEach loop is
   * inside the subscription, this should allow newly added ErrorListeners
   * to still be called.
   */
  void _subscribeListeners(){
    onSyntaxError.listen((e) => errorListeners.forEach((el) => el.syntaxError(
        e.recognizer, e.offendingSymbol, e.line, e.charPositionInLine,
            e.message, e.exception)));
    onAmbiguity.listen((e) => errorListeners.forEach((el) => 
        el.reportAmbiguity(e.recognizer, e.dfa, e.startIndex,
            e.stopIndex, e.exact, e.ambigAlts, e.configs)));
    onAttemptingFullContext.listen((e) => errorListeners.forEach((el) =>
        el.reportAttemptingFullContext(e.recognizer, e.dfa, e.startIndex,
            e.stopIndex, e.ambigAlts, e.configs)));
    onContextSensitivity.listen((e) => errorListeners.forEach((el) =>
        el.reportContextSensitivity(e.recognizer, e.dfa, e.startIndex,
            e.stopIndex, e.prediction, e.configs)));
  }
  
  List<ErrorListener> get errorListeners => _listeners;

  ErrorListener get errorListenerDispatch {
    return new ProxyErrorListener(errorListeners);
  }
  
  /**
   *  Throws [NullThrownError] if [listener] is `null`.
   *  Deprecated. Use [onError.listen](void f(Error e)) in new code, where
   *  f should handle each of the error types in src/errors.dart
   */  
  void addErrorListener(ErrorListener listener) {
    if (listener == null) throw new NullThrownError();
    _listeners.add(listener);
  }

  /**
   * Deprecated. Save [StreamSubscription]s from [onError.listen] and 
   * [StreamSubscription.cancel] them when they are not longer required.
   */
  void removeErrorListener(ErrorListener listener) {
    _listeners.remove(listener);
  }
  
  /**
   * Deprecated. No one-for-one replacement, though if all [StreamSubscription]s
   * are saved then they can be [StreamSubscription.cancel]ed individually.
   * 
   * Note this function does not cancel subscriptions made through the new
   * [Stream] interface.
   */  
  void removeErrorListeners() {
    _listeners.clear();
  }
}