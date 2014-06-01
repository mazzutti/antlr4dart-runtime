part of antlr4dart;

///  A token has properties: text, type, line, character position in the line
///  (so we can ignore tabs), token channel, index, and source from which
///  we obtained this token.
abstract class Token {

  static const int INVALID_TYPE = 0;

  ///  During lookahead operations, this "token" signifies we hit rule
  ///  end ATN state and did not follow it despite needing to.
  static const int EPSILON = -2;

  static const int MIN_USER_TOKEN_TYPE = 1;

  static const int EOF = IntSource.EOF;

  ///  All tokens go to the parser (unless skip() is called in that rule)
  ///  on a particular "channel".  The parser tunes to a particular channel
  ///  so that whitespace etc... can go to the parser on a "hidden" channel.
  static const int DEFAULT_CHANNEL = 0;

  ///  Anything on different channel than `DEFAULT_CHANNEL` is not parsed
  ///  by parser.
  static const int HIDDEN_CHANNEL = 1;

  ///  Get the text of the token.
  String get text;

  ///  Get the token type of the token
  int get type;

  ///  The line number on which the 1st character of this token
  ///  was matched, line = 1..n
  int get line;

  ///  The index of the first character of this token relative to the
  ///  beginning of the line at which it occurs, 0..n-1
  int get charPositionInLine;

  ///  Return the channel this token. Each token can arrive at the parser
  ///  on a different channel, but the parser only "tunes" to a single channel.
  ///  The parser ignores everything not on `DEFAULT_CHANNEL`.
  int get channel => 0;

  ///  An index from 0..n-1 of the token object in the token source.
  ///  This must be valid in order to print token source.
  ///
  ///  Return -1 to indicate that this token was conjured up since
  ///  it doesn't have a valid index.
  int get tokenIndex;

  ///  The starting character index of the token
  ///  This method is optional; return -1 if not implemented.
  int get startIndex;

  ///  The last character index of the token.
  ///  This method is optional; return -1 if not implemented.
  int get stopIndex;

  ///  Gets the [TokenProvider] which created this token.
  TokenProvider get tokenProvider;

  /// Gets the [CharSource] from which this token was derived.
  CharSource get charSource;
}
