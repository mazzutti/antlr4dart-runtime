part of antlr4dart;

class ConsoleErrorListener extends BaseErrorListener {

  static final ConsoleErrorListener INSTANCE = new ConsoleErrorListener();

  void syntaxError(Recognizer recognizer,
                   Object offendingSymbol,
                   int line,
                   int charPositionInLine,
                   String msg,
                   RecognitionException e) {
    print("line $line:$charPositionInLine $msg");
  }
}
