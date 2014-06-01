part of antlr4dart;

/// This implementation of [ErrorListener] dispatches all calls to a
/// collection of delegate listeners. This reduces the effort required
/// to support multiple listeners.
class ProxyErrorListener implements ErrorListener {
  final Iterable delegates;

  ProxyErrorListener(this.delegates) {
    assert(delegates != null);
  }

  void syntaxError(Recognizer recognizer,
                   Object offendingSymbol,
                   int line,
                   int charPositionInLine,
                   String msg,
                   RecognitionException e) {
    delegates.forEach((d) {
      d.syntaxError(recognizer, offendingSymbol, line, charPositionInLine, msg, e);
    });
  }

  void reportAmbiguity(Parser recognizer,
                       Dfa dfa,
                       int startIndex,
                       int stopIndex,
                       bool exact,
                       BitSet ambigAlts,
                       AtnConfigSet configs) {
    delegates.forEach((d) {
      d.reportAmbiguity(recognizer, dfa, startIndex, stopIndex, exact, ambigAlts, configs);
    });
  }

  void reportAttemptingFullContext(Parser recognizer,
                                   Dfa dfa,
                                   int startIndex,
                                   int stopIndex,
                                   BitSet conflictingAlts,
                                   AtnConfigSet configs) {
    delegates.forEach((d) {
      d.reportAttemptingFullContext(recognizer, dfa, startIndex, stopIndex, conflictingAlts, configs);
    });
  }

  void reportContextSensitivity(Parser recognizer,
                                Dfa dfa,
                                int startIndex,
                                int stopIndex,
                                int prediction,
                                AtnConfigSet configs) {
    delegates.forEach((d) {
      d.reportContextSensitivity(recognizer, dfa, startIndex, stopIndex, prediction, configs);
    });
  }
}
