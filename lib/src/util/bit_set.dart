part of antlr4dart;

/// This class implements a vector of bits that grows as needed. Each
/// component of the bit set has a `bool` value. The
/// bits of a `BitSet` are indexed by nonnegative ints.
/// Individual indexed bits can be examined, set, or cleared. One
/// `BitSet` may be used to modify the contents of another
/// `BitSet` through logical AND, logical inclusive OR, and
/// logical exclusive OR operations.
///
/// By default, all bits in the set initially have the value `false`.
///
/// Every bit set has a current size, which is the number of bits
/// of space currently in use by the bit set. Note that the size is
/// related to the implementation of a bit set, so it may change with
/// implementation. The length of a bit set relates to logical length
/// of a bit set and is defined independently of implementation.
///
/// Unless otherwise noted, passing a null parameter to any of the
/// methods in a `BitSet` will result in a [NullThrownError].
///
class BitSet {

  // The bits in this BitSet.
  BigInteger _word;

  /// Creates an empty bit set.
  BitSet() {
    _word = BigInteger.ZERO;
  }

  /// Returns a hash code value for this bit set. The hash code
  /// depends only on which bits have been set within this
  /// `BitSet`. The algorithm used to compute it may be described
  /// as follows.
  ///
  ///     int get hashCode {
  ///       var h = new BigInteger(1234);
  ///       h ^= _word;
  ///       return ((h >> 32) ^ h).intValue();
  ///     }
  ///
  /// Note that the hash code values change if the set of bits is altered.
  ///
  /// Return  a hash code value for this bit set.
  int get hashCode {
    var h = new BigInteger(1234);
    h ^= _word;
    return ((h >> 32) ^ h).intValue();
  }

  /// Returns the "logical size" of this [BitSet]: the index of the highest
  /// set bit in the [BitSet] plus one. Returns zero if the [BitSet] contains
  /// no set bits.
  ///
  /// Return the logical size of this [BitSet].
  int get length => _word.bitLength();

  /// Returns true if this [BitSet] contains no bits that are set to `true`.
  bool get isEmpty => _word == BigInteger.ZERO;

  /// Returns the number of bits set to `true` in this [BitSet].
  int get cardinality => _word.bitCount();

  /// Sets the bit at the specified index to the specified [value].
  ///
  /// [bitIndex] is a bit index.
  ///
  /// A [RangeError] occurs when the specified index is negative.
  void set(int bitIndex, [bool value = false]) {
    if (value) {
      if (bitIndex < 0) throw new RangeError("bitIndex < 0: $bitIndex");
      _word = _word.setBit(bitIndex);
    } else {
      clear(bitIndex);
    }
  }

  /// Sets the bit specified by the index to `false`.
  ///
  /// [bitIndex] is the index of the bit to be cleared.
  ///
  /// A [RangeError] occurs when the specified index is negative.
  void clear(int bitIndex) {
    if (bitIndex < 0) throw new RangeError("bitIndex < 0: $bitIndex");
    _word = _word.clearBit(bitIndex);
  }

  /// Returns the value of the bit with the specified index. The value is
  /// `true` if the bit with the index [bitIndex] is currently set in this
  /// [BitSet]; otherwise, the result is `false`.
  ///
  /// [bitIndex] is the bit index
  ///
  /// A [RangeError] occurs when the specified index is negative.
  bool get(int bitIndex) {
    if (bitIndex < 0) throw new RangeError("bitIndex < 0: $bitIndex");
    return _word.testBit(bitIndex);
  }

  /// Returns the index of the first bit that is set to `true` that occurs on
  /// or after the specified starting index. If no such bit exists then
  /// `code -1` is returned.
  ///
  /// To iterate over the `true` bits in a [BitSet],
  /// use the following loop:
  ///
  ///      for (int i = bs.nextSetBit(0); i >= 0; i = bs.nextSetBit(i+1)) {
  ///        // operate on index i here
  ///      }
  ///
  /// [fromIndex] is the index to start checking from (inclusive).
  ///
  /// A [RangeError] occurs when the specified index is negative.
  int nextSetBit(int fromIndex) {
    if (fromIndex < 0) throw new RangeError("fromIndex < 0: $fromIndex");
    var size = _word.bitLength();
    for (int i = fromIndex; i < size;i++) {
      if (_word.testBit(i)) return i;
    }
    return -1;
  }

  /// Returns the index of the first bit that is set to `false` that occurs on
  /// or after the specified starting index.
  ///
  /// [fromIndex] is the index to start checking from (inclusive)
  ///
  /// A [RangeError] occurs when the specified index is negative.
  int nextClearBit(int fromIndex) {
    if (fromIndex < 0) throw new RangeError("fromIndex < 0: $fromIndex");
    var size = _word.bitLength();
    for (int i = fromIndex; i < size;i++) {
      if (!_word.testBit(i)) return i;
    }
    return -1;
  }

  /// Performs a logical **OR** of this bit set with the bit set argument.
  ///
  /// This [BitSet] is modified so that a bit in it has the value `true` if
  /// and only if it either already had the value `true` or the corresponding
  /// bit in the bit set argument has the value `true`.
  void or(BitSet bitSet) {
    if (this != bitSet) _word |= bitSet._word;
  }

  /// Compares this object against the specified object.
  ///
  /// The result is `true` if and only if the argument is not `null` and is
  /// a [Bitset] object that has exactly the same set of bits set to `true`
  /// as this bit set. That is, for every nonnegative `int` index `k`,
  /// `(other as BitSet).get(k) == this.get(k)` must be true. The current
  /// sizes of the two bit sets are not compared.
  ///
  /// [other] is the the object to compare with.
  ///
  /// Return `true` if the objects are the same;`false` otherwise.
  bool operator==(Object other) {
    return other is BitSet ? _word == other._word : false;
  }

  /// Returns a string representation of this bit set.
  ///
  /// For every index for which this [BitSet] contains a bit in the set state,
  /// the decimal representation of that index is included in the result.
  /// Such indices are listed in order from lowest to highest, separated
  /// by ",&nbsp;" (a comma and a space) and surrounded by braces,
  /// resulting in the usual mathematical notation for a set of integers.
  ///
  /// Example:
  ///
  ///     BitSet drPepper = new BitSet();
  ///
  /// Now `drPepper.toString()` returns `"{}"`.
  ///
  ///     drPepper.set(2, true);
  ///
  /// Now  `drPepper.toString()` returns `"{2}"`.
  ///
  ///     drPepper.set(4, true);
  ///     drPepper.set(10, true);
  ///
  /// Now `drPepper.toString()` returns `"{2, 4, 10}"`.
  ///
  /// Return a string representation of this bit set.
  String toString() {
    StringBuffer sb = new StringBuffer('{');
    int i = nextSetBit(0);
    if (i != -1) {
      sb.write(i);
      for (i = nextSetBit(i+1); i >= 0; i = nextSetBit(i+1)) {
        int endOfRun = nextClearBit(i);
        do {
          sb
              ..write(", ")
              ..write(i);
        } while (++i < endOfRun);
      }
    }
    sb.write('}');
    return sb.toString();
  }
}
