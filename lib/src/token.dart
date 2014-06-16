part of antlr4dart;

/// The default mechanism for creating tokens. It's used by default in [Lexer]
/// and the error handling strategy (to create missing tokens). Notifying the
/// parser of a new factory means that it notifies it's token source and error
/// strategy.
///
/// This is the method used to create tokens in the lexer and in the error
/// handling strategy. If `text != null`, than the `start` and `stop` positions
/// are wiped to `-1` in the text override is set in the [CommonToken].
typedef T TokenFactory<T extends Token> (
  Pair<TokenProvider, StringSource> source,
  int type,
  String text,
  int channel,
  int start,
  int stop,
  int line,
  int charPositionInLine);


class CommonTokenFactory {

  static final TokenFactory<CommonToken> DEFAULT = new CommonTokenFactory();

  // Copy text for token out of input char source. Useful when input
  // source is unbuffered.
  final bool _copyText;

  /// Create factory and indicate whether or not the factory copy
  /// text out of the char source.
  CommonTokenFactory([this._copyText = false]);

  CommonToken call(Pair<TokenProvider, StringSource> source,
                   int type,
                   String text,
                   int channel,
                   int start,
                   int stop,
                   int line,
                   int charPositionInLine) {
    CommonToken t = new CommonToken(source, type, channel, start, stop);
    t.line = line;
    t.charPositionInLine = charPositionInLine;
    if (text != null) {
      t.text = text;
    } else if (_copyText && source.b != null) {
      t.text = source.b.getText(Interval.of(start, stop));
    }
    return t;
  }

}

/// A token has properties: text, type, line, character position in the line
/// (so we can ignore tabs), token channel, index, and source from which
/// we obtained this token.
abstract class Token {

  static const int INVALID_TYPE = 0;

  static const int MIN_USER_TOKEN_TYPE = 1;

  /// The value returned by [lookAhead] when the end of the source is
  /// reached.
  static const int EOF = -1;

  /// During lookahead operations, this "token" signifies we hit rule
  /// end ATN state and did not follow it despite needing to.
  static const int EPSILON = -2;

  /// All tokens go to the parser (unless skip() is called in that rule)
  /// on a particular "channel".  The parser tunes to a particular channel
  /// so that whitespace etc... can go to the parser on a "hidden" channel.
  static const int DEFAULT_CHANNEL = 0;

  /// Anything on different channel than `DEFAULT_CHANNEL` is not parsed
  /// by parser.
  static const int HIDDEN_CHANNEL = 1;

  /// The text of the token.
  String get text;

  /// The token type of the token
  int get type;

  /// The line number on which the 1st character of this token
  /// was matched, line = 1..n
  int get line;

  /// The index of the first character of this token relative to the
  /// beginning of the line at which it occurs, 0..n-1
  int get charPositionInLine;

  /// Return the channel this token. Each token can arrive at the parser
  /// on a different channel, but the parser only "tunes" to a single channel.
  /// The parser ignores everything not on `DEFAULT_CHANNEL`.
  int get channel => 0;

  /// An index from 0..n-1 of the token object in the token source.
  /// This must be valid in order to print token source.
  ///
  /// Return -1 to indicate that this token was conjured up since
  /// it doesn't have a valid index.
  int get tokenIndex;

  /// The starting character index of the token
  /// This method is optional; return -1 if not implemented.
  int get startIndex;

  /// The last character index of the token.
  /// This method is optional; return -1 if not implemented.
  int get stopIndex;

  /// The [TokenProvider] which created this token.
  TokenProvider get tokenProvider;

  /// The [StringSource] from which this token was derived.
  StringSource get stringSource;
}

abstract class WritableToken extends Token {
  void set text(String text);

  void set type(int type);

  void set line(int line);

  void set charPositionInLine(int pos);

  void set channel(int channel);

  void set tokenIndex(int index);
}

class CommonToken implements WritableToken {
  static final _EMPTY_SOURCE = new Pair(null, null);

  Pair<TokenProvider, StringSource> _source;

  String _text;

  int type;

  int line = 0;

  int charPositionInLine = -1; // set to invalid position

  int channel= Token.DEFAULT_CHANNEL;

  /// What token number is this from 0..n-1 tokens; < 0 implies invalid index.
  int tokenIndex = -1;

  /// The char position into the input buffer where this token starts.
  int startIndex = 0;

  /// The char position into the input buffer where this token stops.
  int stopIndex = 0;

  CommonToken(this._source,
              this.type,
              this.channel,
              this.startIndex,
              this.stopIndex) {
    if (_source.a != null) {
      line = _source.a.line;
      charPositionInLine = _source.a.charPositionInLine;
    }
  }

  CommonToken.ofType(this.type, [String text]) {
    if (text != null) {
      channel = Token.DEFAULT_CHANNEL;
      _text = text;
    }
    _source = _EMPTY_SOURCE;
  }

  CommonToken.from(Token oldToken) {
    text = oldToken.text;
    type = oldToken.type;
    line = oldToken.line;
    tokenIndex = oldToken.tokenIndex;
    charPositionInLine = oldToken.charPositionInLine;
    channel = oldToken.channel;
    startIndex = oldToken.startIndex;
    stopIndex = oldToken.stopIndex;
    if (oldToken is CommonToken) {
      _source = oldToken._source;
    } else {
      _source = new Pair<TokenProvider,
          StringSource>(oldToken.tokenProvider, oldToken.stringSource);
    }
  }

  String get text {
    if (_text != null) return _text;
    StringSource input = stringSource;
    if (input == null) return null;
    int n = input.length;
    if (startIndex < n && stopIndex < n) {
      return input.getText(Interval.of(startIndex, stopIndex));
    } else {
      return "<EOF>";
    }
  }

  /// Override the text for this token.
  ///
  /// `getText` will return this text rather than pulling from the buffer.
  ///
  /// Note that this does not mean that start/stop indexes are not valid.
  /// It means that that input was converted to a new string in the token
  /// object.
  void set text(String text) {
    _text = text;
  }

  TokenProvider get tokenProvider => _source.a;

  StringSource get stringSource => _source.b;

  String toString() {
    String channelStr = "";
    if (channel > 0) channelStr = ",channel=$channel";
    String txt = text;
    if (txt != null) {
      txt = txt.replaceAll("\n","\\n");
      txt = txt.replaceAll("\r","\\r");
      txt = txt.replaceAll("\t","\\t");
    } else {
      txt = "<no text>";
    }
    return "[@$tokenIndex,$startIndex:$stopIndex="
      "'$txt',<$type>$channelStr,$line:$charPositionInLine]";
  }
}

