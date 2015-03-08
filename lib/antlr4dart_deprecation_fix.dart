/**
 * Some changes to the recognizer interface occurred as of release 0.7.0
 * involving error listening. The old system of [ErrorListener]s was replaced
 * by a more dart-ish [Stream] interface.
 * 
 * Old code that used the [ErrorListener] interface can be easily re-written
 * without the use of this package. However, for situations where the code
 * base is large and a quick fix is required, this library provides a two-
 * line solution.
 * 
 * For each [Recognizer] using the old [ErrorListener] interface, mix in 
 * [DeprecatedRecognizerMixin], and before use (presumably in the constructor),
 * call [deprecatedRecognizerMixinInit]().
 * 
 * Old broken code
 *     class MyLanguageSpecificParser extends Parser{
 *       MyLanguageSpecificParser();
 *       
 *       //stuff involving funcitons removed from the Recognizer API
 *       //throw NoSuchMethodErrors
 *     }
 * 
 * New code
 *     class MyLanguageSpecificParser extends Parser with DeprecatedRecognizerMixin{
 *       MyLanguageSpecificParser(){
 *         deprecatedRecognizerMixinInit();
 *         //functions removed from the Recognizer API now work as expected.
 *       }
 * 
 *       //stuff involving functions removed from the Recognizer API execute!
 *     }
 */

@deprecated
library antlr4dart.deprecation_fix;

export 'src/deprecation_fix/deprecation_fix.dart';