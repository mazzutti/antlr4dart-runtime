part of antlr4dart;

abstract class WritableToken extends Token {
  void set text(String text);

  void set type(int ttype);

  void set line(int line);

  void set charPositionInLine(int pos);

  void set channel(int channel);

  void set tokenIndex(int index);
}
