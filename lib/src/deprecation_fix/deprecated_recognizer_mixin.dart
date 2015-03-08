part of antlr4dart.deprecation_fix;
/**
 * Mixin for back-compatibility of Recognizer with deprecation of
 * [ErrorListener].
 * 
 * Functions very similarly to [DeprecatedParserMixin] except only forwards
 * [SyntaxError]s. If you are fixing a parser, use the parse mixin. If you are
 * fixing a non-parser recognizer (e.g. lexer) user this mixin. Do no use both.
 * 
 * Usage: while users are encouraged to re-write code using [ErrorListener]s
 * with the [Stream]-based interface around [Recognizer].on*, this mixin class
 * allows old recognizers to work almost immediately.
 * 
 * [deprecatedMixinInit] must be called before back-compatibility
 * works as expected.
 * 
 * Old broken code
 *     class MyLanguageSpecificRecognizer extends Recognizer{
 *       MyLanguageSpecificRecognizer();
 *       
 *       //stuff involving funcitons removed from the Recognizer API
 *       //throw NoSuchMethodErrors
 *     }
 * 
 * New code
 *     class MyLanguageSpecificRecognizer extends Recognizer with DeprecatedRecognizerMixin{
 *       MyLanguageSpecificRecognizer(){
 *         deprecatedRecognizerMixinInit();
 *         //functions removed from the Recognizer API now work as expected.
 *       }
 * 
 *       //stuff involving functions removed from the Recognizer API execute!
 *     }
 */
abstract class DeprecatedRecognizerMixin implements Recognizer{
  List<ErrorListener> _listeners = new List<ErrorListener>();
  
  /**
   * Must be called after recognizer creation in order for deprecation fixes
   * to work.
   */
  void deprecatedMixinInit({bool autoAddConsoleErrorListener: true}){
    if (autoAddConsoleErrorListener){
      _listeners.add(ConsoleErrorListener.INSTANCE);
    }
    //temporary fix.
    _subscribeListeners();
  }
  
  /**
   * Sets up subscriptions to [errorListener]s. Since the forEach loop is
   * inside the subscription, this should allow newly added ErrorListeners
   * to still be called.
   */
  void _subscribeListeners(){
    onSyntaxError.listen((e) => errorListeners.forEach((el) => el.syntaxError(
        e.recognizer, e.offendingSymbol, e.line, e.charPositionInLine,
            e.message, e.exception)));
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
   */  
  void removeErrorListeners() {
    _listeners.clear();
  }
}