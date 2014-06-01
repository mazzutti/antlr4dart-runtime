part of antlr4dart;

///  A token provider must provide a sequence of tokens via `nextToken()`
///  and also must reveal it's source of characters; [CommonToken]'s text is
///  computed from a [CharSource]; it only store indices into the character
///  source.
///
///  Errors from the lexer are never passed to the parser.  Either you want
///  to keep going or you do not upon token recognition error.  If you do not
///  want to continue lexing then you do not want to continue parsing.  Just
///  throw an exception not under [RecognitionException] and Dart will naturally
///  toss you all the way out of the recognizers.  If you want to continue
///  lexing then you should not throw an exception to the parser -- it has already
///  requested a token.  Keep lexing until you get a valid one.  Just report
///  errors and keep going, looking for a valid token.
abstract class TokenProvider {

  int get line;

  int get charPositionInLine;

  /// From what character source was this token created?  You don't have to
  /// implement but it's nice to know where a Token comes from if you have
  /// include files etc... on the input.
  CharSource get inputSource;

  /// Where are you getting tokens from? normally the implication will simply
  /// ask lexers input source.
  String get sourceName;

  /// Optional method that lets users set factory in lexer or other source
  void set tokenFactory(TokenFactory factory);

  /// Gets the factory used for constructing tokens.
  TokenFactory get tokenFactory;

  /// Return a Token object from your input source (usually a [CharSource]).
  /// Do not fail/return upon lexing error; keep chewing on the characters
  /// until you get a good one; errors are not passed through to the parser.
  Token nextToken();
}
