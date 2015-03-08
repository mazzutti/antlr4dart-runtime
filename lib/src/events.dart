part of antlr4dart;

abstract class RecognizerEvent{
  final Recognizer recognizer;
  RecognizerEvent(this.recognizer);
}

abstract class ParserEvent extends RecognizerEvent{
  @override
  Parser get recognizer;
  
  final Dfa dfa;
  final int startIndex;
  final int stopIndex;
  final AtnConfigSet configs;
  
  ParserEvent(Parser recognizer, this.dfa, this.startIndex, this.stopIndex,
      this.configs): super(recognizer);
}

/// [Error] emitted from a recognizer - generally a [Lexer]. If receiving from
/// a [Parser], this error is usually a [ParserSyntaxError].
/// 
/// The [RecognitionException] is non-null for all syntax errors except
/// when we discover mismatched token errors that we can recover from
/// in-line, without returning from the surrounding rule (via the single
/// token insertion and deletion mechanism).
///
/// [recognizer] is the recognizer where got the error. From this object, you
/// can access the context as well as the input source.
/// If no viable alternative error, [exception] has token at which we started 
/// production for the decision.
/// [line] is the line number in the input where the error occurred.
/// [charPositionInLine] is the character position within that line where
/// the error occurred.
/// [message] is the message to emit.
/// [exception] is the exception generated by the parser that led to the
/// reporting of an error. It is `null` in the case where the parser was
/// able to recover in line without exiting the surrounding rule.
class SyntaxError extends Error implements RecognizerEvent{
  final Recognizer recognizer;
  final int line;
  final int charPositionInLine;
  final String message;
  final RecognitionException exception;
  
  /**
   * [ParserSyntaxError]s are a subclass with an [offendingSymbol].
   * These errors likely arose from a [Lexer], which is responsible for
   * creating the [Token]s itself, so you should not rely on this [Token] being
   * anything except null. If you know this came from a [ParserSyntaxError]
   * (which has a non-deprecated offendingSymbol getter), recast this.
   */
  @deprecated
  Token get offendingSymbol => null;
  
  SyntaxError(
      this.recognizer,
      this.line,
      this.charPositionInLine,
      this.message,
      this.exception
  );
  
  @override
  String toString() => "Syntax error, line $line:$charPositionInLine $message";
}

/// Specialized [SyntaxError] emitted from a [Parser].
/// 
/// Largely the same, except [offendingSymbol] is the offending token in the
/// input token source.
class ParserSyntaxError extends Error implements SyntaxError{
  final Recognizer recognizer;
  
  /**
   * [ParserSyntaxError]s implement [SyntaxError] along with a reference to the
   * [offendingSymbol].
   */
  final Token offendingSymbol;
  int get line => offendingSymbol.line;
  int get charPositionInLine => offendingSymbol.charPositionInLine;
  final String message;
  final RecognitionException exception;
  
  ParserSyntaxError(
      this.recognizer,
      this.offendingSymbol,
      this.message,
      this.exception
  );
  
  @override
  String toString() => "Syntax error, line $line:$charPositionInLine $message"; 
}

/// These events are sent by the parser when a full-context prediction
/// results in an ambiguity.
///
/// When [exact] is `true`, **all** of the alternatives in [ambigAlts] are
/// viable, i.e. this is reporting an exact ambiguity.
/// [exact] is `false`, **at least two** of the alternatives in [ambigAlts]
/// are viable for the current input, but the prediction algorithm terminated
/// as soon as it determined that at least the **minimum** alternative in
/// [ambigAlts] is viable.
///
/// When the [PredictionMode.LL_EXACT_AMBIG_DETECTION] prediction mode
/// is used, the parser is required to identify exact ambiguities so
/// [exact] will always be `true`.
///
/// This method is not used by lexers.
///
/// [recognizer] is the parser instance.
/// [dfa] is the DFA for the current decision.
/// [startIndex] is the input index where the decision started.
/// [stopIndex] is the input input where the ambiguity is reported.
/// [exact] is `true` if the ambiguity is exactly known, otherwise `false`.
/// This is always `true` when [PredictionMode.LL_EXACT_AMBIG_DETECTION]
/// is used.
/// [ambigAlts] is the potentially ambiguous alternatives.
/// [configs] is the ATN configuration set where the ambiguity was
/// determined.
class AmbiguityEvent extends ParserEvent{
  final bool exact;
  final BitSet ambigAlts;
  
  AmbiguityEvent(
    Parser recognizer,
    Dfa dfa,
    int startIndex,
    int stopIndex,
    this.exact,
    this.ambigAlts,
    AtnConfigSet configs
  ): super(recognizer, dfa, startIndex, stopIndex, configs);
}

/// These events are fired when an SLL conflict occurs and the parser is about
/// to use the full context information to make an LL decision.
///
/// If one or more configurations in [configs] contains a semantic
/// predicate, the predicates are evaluated before this method is called.
/// The subset of alternatives which are still viable after predicates are
/// evaluated is reported in [conflictingAlts].
///
/// This method is not used by lexers.
///
/// [recognizer] is the parser instance.
/// [dfa] is the DFA for the current decision.
/// [startIndex] is the input index where the decision started.
/// [stopIndex] is the input index where the SLL conflict occurred.
/// [conflictingAlts] is the specific conflicting alternatives. If this is
/// `null`, the conflicting alternatives are all alternatives represented
/// in [configs].
/// [configs] is the ATN configuration set where the SLL conflict was
/// detected.
class AttemptingFullContextEvent extends ParserEvent{
  final BitSet ambigAlts;
  
  AttemptingFullContextEvent(
    Parser recognizer,
    Dfa dfa,
    int startIndex,
    int stopIndex,
    this.ambigAlts,
    AtnConfigSet configs
  ): super(recognizer, dfa, startIndex, stopIndex, configs);
}

/// These events are fired by the parser when a full-context prediction has a
/// unique result.
///
/// For prediction implementations that only evaluate full-context
/// predictions when an SLL conflict is found (including the default
/// [ParserAtnSimulator] implementation), this method reports cases
/// where SLL conflicts were resolved to unique full-context predictions,
/// i.e. the decision was context-sensitive. This report does not necessarily
/// indicate a problem, and it may appear even in completely unambiguous
/// grammars.
///
/// [configs] may have more than one represented alternative if the
/// full-context prediction algorithm does not evaluate predicates before
/// beginning the full-context prediction. In all cases, the final prediction
/// is passed as the [prediction] argument.
///
/// This method is not used by lexers.
///
/// [recognizer] is the parser instance.
/// [dfa] is the DFA for the current decision.
/// [startIndex] the input index where the decision started.
/// [stopIndex] is the input index where the context sensitivity was
/// finally determined.
/// [prediction] is the unambiguous result of the full-context prediction.
/// [configs] is the ATN configuration set where the unambiguous prediction
/// was determined.
class ContextSensitivityEvent extends ParserEvent{
  final int prediction;
  
  ContextSensitivityEvent(
    Parser recognizer,
    Dfa dfa,
    int startIndex,
    int stopIndex,
    this.prediction,
    AtnConfigSet configs
  ): super(recognizer, dfa, startIndex, stopIndex, configs);
}