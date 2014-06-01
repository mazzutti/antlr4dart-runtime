part of antlr4dart;

/// An [IntSource] whose symbols are [Token] instances.
abstract class TokenSource extends IntSource {
  /// Get the [Token] instance associated with the value returned by
  /// `lookAhead(k)`. This method has the same pre- and post-conditions as
  /// [IntSource.lookAhead]. In addition, when the preconditions of this method
  /// are met, the return value is non-null and the value of
  /// `lookToken(k).type == lookAhead(k)`.
  Token lookToken(int k);

  /// Gets the [Token] at the specified `index` in the source. When
  /// the preconditions of this method are met, the return value is non-null.
  ///
  /// The preconditions for this method are the same as the preconditions of
  /// [IntSource.seek]. If the behavior of `seek(index)` is unspecified for
  /// the current state and given {@code index}, then the behavior of this
  /// method is also unspecified.
  ///
  /// The symbol referred to by `index` differs from `seek()` only
  /// in the case of filtering sources where `index` lies before the end
  /// of the source. Unlike `seek()`, this method does not adjust
  /// `index` to point to a non-ignored symbol.
  ///
  /// Throws ArgumentError if `index` is less than 0.
  /// Throws UnsupportedError if the source does not support
  /// retrieving the token at the specified index
  Token get(int index);

  /// Gets the underlying [TokenProvider] which provides tokens for this
  /// source.
  TokenProvider get tokenProvider;

  /// Return the text of all tokens within the specified `interval`. This
  /// method behaves like the following code (including potential exceptions
  /// for violating preconditions of [get], but may be optimized by the
  /// specific implementation.
  ///
  ///      TokenSource source = ...;
  ///      String text = "";
  ///      for (int i = interval.a; i <= interval.b; i++) {
  ///        text += source.get(i).text;
  ///      }
  ///
  /// [interval] is the interval of tokens within this source to get text
  /// for.
  /// Return The text of all tokens within the specified interval in this
  /// source.
  ///
  /// Throws [NullthrownError] if `interval` is `null`
  String getTextIn(Interval interval);

  /// Return the text of all tokens in the source. This method behaves like the
  /// following code, including potential exceptions from the calls to
  /// [IntSource.length] and [getTextIn]`(`[Interval]`)`, but may be
  /// optimized by the specific implementation.
  ///
  ///      TokenSource source = ...;
  ///      String text = source.getTextIn(new Interval(0, source.length));
  ///
  /// Return the text of all tokens in the source.
  String get text;

  /// Return the text of all tokens in this source between `start` and
  /// `stop` Token (inclusive).
  ///
  /// If the specified `start` or `stop` token was not provided by
  /// this source, or if the `stop` occurred before the `start`
  /// token, the behavior is unspecified.
  ///
  /// For sources which ensure that the [Token.tokenIndex] getter is
  /// accurate for all of its provided tokens, this method behaves like the
  /// following code. Other sources may implement this method in other ways
  /// provided the behavior is consistent with this at a high level.
  ///
  ///      TokenSource source = ...;
  ///      String text = "";
  ///      for (int i = start.tokenIndex; i <= stop.tokenIndex; i++) {
  ///        text += source.get(i).text;
  ///      }
  ///
  /// [start] is the first token in the interval to get text for.
  /// [stop] is the last token in the interval to get text for (inclusive).
  /// Return the text of all tokens lying between the specified `start`
  /// and `stop` tokens.
  ///
  /// Throws [UnsupportedError] if this source does not support
  /// this method for the specified tokens.
  String getText(Token start, Token stop);
}
