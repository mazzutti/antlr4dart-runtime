part of antlr4dart;

/**
 * A simple source of symbols whose values are represented as integers. This
 * interface provides __marked ranges__ with support for a minimum level
 * of buffering necessary to implement arbitrary lookahead during prediction.
 * For more information on marked ranges, see [mark].
 *
 * **Initializing Methods:** Some methods in this interface have
 * unspecified behavior if no call to an initializing method has occurred after
 * the source was constructed. The following is a list of initializing methods:
 *
 *   * [lookAhead]
 *   * [consume]
 *   * [length]
 */
abstract class IntSource {
  /**
   * The value returned by [lookAhead] when the end of the source is
   * reached.
   */
  static const int EOF = -1;

  /**
   * The value returned by [sourceName] when the actual name of the
   * underlying source is not known.
   */
  static const String UNKNOWN_SOURCE_NAME = "<unknown>";

  /**
   * Returns the total number of symbols in the source, including a single EOF
   * symbol.
   *
   * Throws UnsupportedError if the size of the source is unknown.
   */
  int get length;

  /**
   * Gets the name of the underlying symbol source. This method returns a
   * non-null, non-empty string. If such a name is not known, this method
   * returns [UNKNOWN_SOURCE_NAME].
   */
  String get sourceName;

  /**
   * A mark provides a guarantee that [seek] operations will be valid over
   * a "marked range" extending from the index where [mark] was called to
   * the current[index]. This allows the use of input sources by specifying
   * the minimum buffering requirements to support arbitrary lookahead during
   * prediction.
   *
   * The returned mark is an opaque handle (type `int`) which is passed
   * to [release] when the guarantees provided by the marked range are no
   * longer necessary. When calls to `mark`/`release()` are nested, the
   * marks must be released in reverse order of which they were obtained.
   * Since marked regions are used during performance-critical sections of
   * prediction, the specific behavior of invalid usage is unspecified (i.e.
   * a mark is not released, or a mark is released twice, or marks are not
   * released in reverse order from which they were created).
   *
   * The behavior of this method is unspecified if no call to an [IntSource]
   * initializing method has occurred after this source was constructed.
   *
   * This method does not change the current position in the input source.
   *
   * The following example shows the use of [mark], [release], [index], and
   * [seek] as part of an operation to safely work within a marked region,
   * then restore the source position to its original value and release the mark.
   *
   *      IntSource source = ...;
   *      int index = -1;
   *      int mark = source.mark;
   *      try {
   *        index = source.index;
   *        // perform work here...
   *      } finally {
   *        if (index != -1) {
   *          source.seek(index);
   *        }
   *        source.release(mark);
   *      }
   *
   * Return an opaque marker which should be passed to [release] when the marked
   * range is no longer required.
   */
  int get mark;

  /**
   * Return the index into the source of the input symbol referred to by
   * `lookAhead(1)`.
   *
   * The behavior of this method is unspecified if no call to an [IntSource]
   * initializing method has occurred after this source was constructed.
   */
  int get index;

  /**
   * Consumes the current symbol in the source. This method has the following
   * effects:
   *
   *  * **Forward movement:** The value of [index] before calling this method
   *    is less than the value of [index] after calling this method.</li>
   *  * **Ordered lookahead:** The value of `lookAhead(1)` before calling this
   *    method becomes the value of `lookAhead(1)` after calling this method.
   *
   * Note that calling this method does not guarantee that [index] is
   * incremented by exactly 1, as that would preclude the ability to implement
   * filtering sources (e.g. [CommonTokenSource] which distinguishes
   * between "on-channel" and "off-channel" tokens).
   *
   * Throws [StateError] if an attempt is made to consume the the end of the
   * source (i.e. if `lookAhead(1) == EOF` before calling `consume`).
   */
  void consume();

  /**
   * Gets the value of the symbol at offset `i` from the current
   * position. When `i == 1`, this method returns the value of the current
   * symbol in the source (which is the next symbol to be consumed). When
   * `i == -1`, this method returns the value of the previously read
   * symbol in the source. It is not valid to call this method with
   * `i == 0`, but the specific behavior is unspecified because this
   * method is frequently called from performance-critical code.
   *
   * This method is guaranteed to succeed if any of the following are true:
   *
   * * `i > 0`
   * * `i == -1` and [index] returns a value greater than the value of
   *   [index] after the source was constructed and `lookAhead(1)` was
   *   called in that order. Specifying the current `index` relative to
   *   the index after the source was created allows for filtering
   *   implementations that do not return every symbol from the underlying
   *   source. Specifying the call to `lookAhead(1)` allows for lazily
   *   initialized sources.
   * * `lookAhead(i)` refers to a symbol consumed within a marked region
   *   that has not yet been released.
   *
   *
   * If `i` represents a position at or beyond the end of the source,
   * this method returns [EOF].
   *
   * The return value is unspecified if `i < 0` and fewer than `-i` calls
   * to [consume] have occurred from the beginning of the source before
   * calling this method.
   *
   * Throws [UnsupportedError] if the source does not support retrieving
   * the value of the specified symbol.
   */
  int lookAhead(int i);

  /**
   * This method releases a marked range created by a call to [mark]. Calls to
   * `release()` must appear in the reverse order of the corresponding calls to
   * `mark`. If a mark is released twice, or if marks are not released in reverse
   * order of the corresponding calls to `mark`, the behavior is unspecified.
   *
   * For more information and an example, see [mark].
   *
   * `marker` is a marker returned by a call to [mark].
   */
  void release(int marker);

  /**
   * Set the input cursor to the position indicated by `index`. If the
   * specified index lies past the end of the source, the operation behaves as
   * though `index` was the index of the EOF symbol. After this method
   * returns without throwing an exception, the at least one of the following
   * will be true.
   *
   *  * `index` will return the index of the first symbol appearing at or
   *    after the specified `index`. Specifically, implementations which
   *    filter their sources should automatically adjust `index` forward the
   *    minimum amount required for the operation to target a non-ignored symbol;
   *  * `lookAhead(1)` returns [EOF].
   *
   * This operation is guaranteed to not throw an exception if `index`
   * lies within a marked region. For more information on marked regions, see
   * [mark]. The behavior of this method is unspecified if no call to
   * an [IntSource] initializing method has occurred after this source
   * was constructed.
   *
   * `index` is the absolute index to seek to.
   *
   * Throws [ArgumentError] if `index` is less than `0`.
   * Throws UnsupportedError if the source does not support seeking to the
   * specified index.
   */
  void seek(int index);
}
