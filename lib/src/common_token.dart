part of antlr4dart;

class CommonToken implements WritableToken {
  static final _EMPTY_SOURCE = new Pair<TokenProvider, CharSource>(null, null);

  Pair<TokenProvider, CharSource> _source;

  String _text;

  int type;

  int line = 0;

  int charPositionInLine = -1; // set to invalid position

  int channel= Token.DEFAULT_CHANNEL;

  /*
   * What token number is this from 0..n-1 tokens; < 0 implies invalid index.
   */
  int tokenIndex = -1;

  /**
   * The char position into the input buffer where this token starts.
   */
  int startIndex = 0;

  /**
   * The char position into the input buffer where this token stops.
   */
  int stopIndex = 0;

  CommonToken(this._source, this.type, this.channel, this.startIndex, this.stopIndex) {
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
          CharSource>(oldToken.tokenProvider, oldToken.charSource);
    }
  }

  String get text {
    if (_text != null) return _text;
    CharSource input = charSource;
    if (input == null) return null;
    int n = input.length;
    if (startIndex < n && stopIndex < n) {
      return input.getText(Interval.of(startIndex, stopIndex));
    } else {
      return "<EOF>";
    }
  }

  /**
   * Override the text for this token. getText() will return this text
   * rather than pulling from the buffer.  Note that this does not mean
   * that start/stop indexes are not valid.  It means that that input
   * was converted to a new string in the token object.
   */
  void set text(String text) {
    _text = text;
  }

  TokenProvider get tokenProvider => _source.a;

  CharSource get charSource => _source.b;

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
