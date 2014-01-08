part of antlr4dart;

/**
 * A source of characters for a antlr4dart lexer.
 */
abstract class CharSource extends IntSource {
  /**
   * This method returns the text for a range of characters within this input
   * source. This method is guaranteed to not throw an exception if the
   * specified `interval` lies entirely within a marked range. For more
   * information about marked ranges, see [IntSource.mark].
   *
   * `interval` is an interval within the source.
   * Return the text of the specified interval.
   *
   * Throws [NullThrownError] if `interval` is `null`.
   * Throws [ArgumentError] if `interval.a < 0`, or if
   * `interval.b < interval.a - 1`, or if `interval.b` lies at or past the end
   * of the source.
   * Throws [UnsupportedError] if the source does not support getting the text
   * of the specified interval.
   */
  String getText(Interval interval);
}
