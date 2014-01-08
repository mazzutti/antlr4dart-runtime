part of antlr4dart;

class BaseErrorListener implements ErrorListener {
  void syntaxError(Recognizer recognizer,
                   Object offendingSymbol,
                   int line,
                   int charPositionInLine,
                   String msg,
                   RecognitionException e) {}

  void reportAmbiguity(Parser recognizer,
                       Dfa dfa,
                       int startIndex,
                       int stopIndex,
                       bool exact,
                       BitSet ambigAlts,
                       AtnConfigSet configs) {}

  void reportAttemptingFullContext(Parser recognizer,
                                   Dfa dfa,
                                   int startIndex,
                                   int stopIndex,
                                   BitSet conflictingAlts,
                                   AtnConfigSet configs) {}

  void reportContextSensitivity(Parser recognizer,
                                Dfa dfa,
                                int startIndex,
                                int stopIndex,
                                int prediction,
                                AtnConfigSet configs) {}
}
