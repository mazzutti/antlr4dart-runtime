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
  // BitSets are packed into arrays of "words."  Currently a word is
  // an int, which consists of 64 bits, requiring 2 address bits.
  static const int _ADDRESS_BITS_PER_WORD = 6;
  static const int _BITS_PER_WORD = 1 << _ADDRESS_BITS_PER_WORD;
  static const int _BIT_INDEX_MASK = _BITS_PER_WORD - 1;

  // Used to shift left or right for a partial word mask.
  static final Int64 _WORD_MASK = Int64.parseHex("ffffffffffffffff");

  // The bits in this BitSet.  The ith bit is stored in bits[i/64] at
  // bit position i % 64 (where bit position 0 refers to the least
  // significant bit and 63 refers to the most significant bit).
  List<Int64> _words;

  // The number of words in the logical size of this BitSet.
  int _wordsInUse = 0;

  // Whether the size of "words" is user-specified.  If so, we assume
  // the user knows what he's doing and try harder to preserve it.
  bool _sizeIsSticky = false;

  /// Creates a bit set whose initial size is large enough to explicitly
  /// represent bits with indices in the range `0` through
  /// `nbits-1`. All bits are initially `false`.
  ///
  /// [nbits] the initial size of the bit set
  /// Throws [ArgumentError] if the specified initial size is negative
  BitSet([int nbits = _BITS_PER_WORD]) {
    // nbits can't be negative; size 0 is OK
    if (nbits < 0)
      throw new ArgumentError("nbits < 0: $nbits");
    _initWords(nbits);
    _sizeIsSticky = true;
  }

  /// Returns a hash code value for this bit set. The hash code
  /// depends only on which bits have been set within this
  /// `BitSet`. The algorithm used to compute it may be described
  /// as follows.
  ///
  /// Suppose the bits in the `BitSet` were to be stored
  /// in a list of [Int64] elements called, say, `words`, in
  /// such a manner that bit `k` is set in the `BitSet` (for
  /// nonnegative values of `k`) if and only if the expression
  /// `((k >> 6) < words.length) && ((words[k >> 6] & (1 < (bit & 0x3F))) != 0)`
  /// is true. Then the following definition of the `hashCode`
  /// method would be a correct implementation of the actual algorithm:
  ///
  ///     int get hashCode {
  ///       int h = 1234;
  ///       for (int i = words.length; --i >= 0;) {
  ///         h ^= words[i] * (i + 1);
  ///       }
  ///       return (int)((h >> 32) ^ h);
  ///
  /// Note that the hash code values change if the set of bits is altered.
  ///
  /// Return  a hash code value for this bit set.
  int get hashCode {
    Int64 h = new Int64(1234);
    for (int i = _wordsInUse; --i >= 0; )
      h ^= _words[i] * (i + 1);
    return ((h >> 32) ^ h).toInt();
  }

  /// Returns the "logical size" of this `BitSet`: the index of
  /// the highest set bit in the `BitSet` plus one. Returns zero
  /// if the `BitSet` contains no set bits.
  ///
  /// Return the logical size of this `BitSet`
  int get length {
    if (_wordsInUse == 0) return 0;
    return _BITS_PER_WORD * (_wordsInUse - 1) +
      (_BITS_PER_WORD - _words[_wordsInUse - 1].numberOfLeadingZeros());
  }

  /// Returns true if this `BitSet` contains no bits that are set
  /// to `true`.
  bool get isEmpty => _wordsInUse == 0;

  /// Returns the number of bits set to `true` in this `BitSet`.
  int get cardinality {
    int sum = 0;
    for (int i = 0; i < _wordsInUse; i++)
      sum += _bitCount(_words[i]);
    return sum;
  }

  /// Sets the bit at the specified index to the specified `value`.
  ///
  /// [bitIndex] is a bit index.
  /// Throws [RangeError] if the specified index is negative.
  void set(int bitIndex, [bool value = false]) {
    if (value) {
      if (bitIndex < 0)
        throw new RangeError("bitIndex < 0: $bitIndex");
      int wordIndex = _wordIndex(bitIndex);
      _expandTo(wordIndex);
      _words[wordIndex] |= (1 << bitIndex); // Restores invariants
      _checkInvariants();
    } else {
      clear(bitIndex);
    }
  }

  /// Sets the bit specified by the index to `false`.
  ///
  /// [bitIndex] is the index of the bit to be cleared
  /// Throws [RangeError] if the specified index is negative.
  void clear(int bitIndex) {
    if (bitIndex < 0)
        throw new RangeError("bitIndex < 0: $bitIndex");
    int wordIndex = _wordIndex(bitIndex);
    if (wordIndex >= _wordsInUse) return;
    _words[wordIndex] &= ~(1 << bitIndex);
    _recalculateWordsInUse();
    _checkInvariants();
  }

  /// Returns the value of the bit with the specified index. The value
  /// is `true` if the bit with the index `bitIndex` is currently set
  /// in this `BitSet`; otherwise, the result is `false`.
  ///
  /// [bitIndex] is the bit index
  /// Return the value of the bit with the specified index.
  /// Throws [RangeError] if the specified index is negative.
  bool get(int bitIndex) {
    if (bitIndex < 0)
      throw new RangeError("bitIndex < 0: $bitIndex");
    _checkInvariants();
    int wordIndex = _wordIndex(bitIndex);
    return (wordIndex < _wordsInUse)
      && ((_words[wordIndex] & (1 << bitIndex)) != 0);
  }

  /// Returns the index of the first bit that is set to `true`
  /// that occurs on or after the specified starting index. If no such
  /// bit exists then `code -1` is returned.
  ///
  /// To iterate over the `true` bits in a `BitSet`,
  /// use the following loop:
  ///
  ///      for (int i = bs.nextSetBit(0); i >= 0; i = bs.nextSetBit(i+1)) {
  ///        // operate on index i here
  ///      }
  ///
  /// [fromIndex] is the index to start checking from (inclusive).
  /// Return the index of the next set bit, or `code -1` if there is no such bit.
  /// Throws [RangeError] if the specified index is negative.
  int nextSetBit(int fromIndex) {
    if (fromIndex < 0)
      throw new RangeError("fromIndex < 0: $fromIndex");
    _checkInvariants();
    int u = _wordIndex(fromIndex);
    if (u >= _wordsInUse) return -1;
    Int64 word = _words[u] & (_WORD_MASK << fromIndex);
    while (true) {
      if (word != 0)
        return (u * _BITS_PER_WORD) + word.numberOfTrailingZeros();
      if (++u == _wordsInUse)
        return -1;
      word = _words[u];
    }
  }

  /// Returns the index of the first bit that is set to `false`
  /// that occurs on or after the specified starting index.
  ///
  /// [fromIndex] is the index to start checking from (inclusive)
  /// Return the index of the next clear bit.
  /// Throws [RangeError] if the specified index is negative
  int nextClearBit(int fromIndex) {
    if (fromIndex < 0)
      throw new RangeError("fromIndex < 0: $fromIndex");
    _checkInvariants();
    int u = _wordIndex(fromIndex);
    if (u >= _wordsInUse) return fromIndex;
    Int64 word = ~_words[u] & (_WORD_MASK << fromIndex);
    while (true) {
      if (word != 0)
        return (u * _BITS_PER_WORD) + word.numberOfTrailingZeros();
      if (++u == _wordsInUse)
        return _wordsInUse * _BITS_PER_WORD;
      word = ~_words[u];
    }
  }

  /// Performs a logical **OR** of this bit set with the bit set
  /// argument. This bit set is modified so that a bit in it has the
  /// value `true` if and only if it either already had the
  /// value `true` or the corresponding bit in the bit set
  /// argument has the value `true`.
  void or(BitSet set) {
    if (this == set) return;
    int wordsInCommon = min(_wordsInUse, set._wordsInUse);
    if (_wordsInUse < set._wordsInUse) {
      _ensureCapacity(set._wordsInUse);
      _wordsInUse = set._wordsInUse;
    }
    // Perform logical OR on words in common
    for (int i = 0; i < wordsInCommon; i++)
      _words[i] |= set._words[i];
    // Copy any remaining words
    if (wordsInCommon < set._wordsInUse)
      _words.setRange(wordsInCommon,
          _wordsInUse - wordsInCommon, set._words, wordsInCommon);
    _checkInvariants();
  }

  /// Compares this object against the specified object.
  /// The result is `true` if and only if the argument is
  /// not `null` and is a `Bitset` object that has
  /// exactly the same set of bits set to `true` as this bit
  /// set. That is, for every nonnegative `int` index `k`,
  /// `(obj as BitSet).get(k) == this.get(k)`
  /// must be true. The current sizes of the two bit sets are not compared.
  ///
  /// [obj] is the the object to compare with
  /// Return `true` if the objects are the same;`false` otherwise.
  bool operator==(Object obj) {
    if (obj is! BitSet) return false;
    BitSet set = obj;
    _checkInvariants();
    set._checkInvariants();
    if (_wordsInUse != set._wordsInUse)
      return false;
    // Check words in use by both BitSets
    for (int i = 0; i < _wordsInUse; i++)
      if (_words[i] != set._words[i])
          return false;
    return true;
  }

  /// Returns a string representation of this bit set. For every index
  /// for which this `BitSet` contains a bit in the set state, the
  /// decimal representation of that index is included in the result.
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
  ///     drPepper.set(2);
  ///
  /// Now  `drPepper.toString()` returns `"{2}"`.
  ///
  ///     drPepper.set(4);
  ///     drPepper.set(10);
  ///
  /// Now `drPepper.toString()` returns `"{2, 4, 10}"`.
  ///
  /// Return a string representation of this bit set.
  String toString() {
    _checkInvariants();
    int numBits = (_wordsInUse > 128) ?
      cardinality : _wordsInUse * _BITS_PER_WORD;
    StringBuffer b = new StringBuffer('{');
    int i = nextSetBit(0);
    if (i != -1) {
      b.write(i);
      for (i = nextSetBit(i+1); i >= 0; i = nextSetBit(i+1)) {
        int endOfRun = nextClearBit(i);
        do { b..write(", ")..write(i); }
        while (++i < endOfRun);
      }
    }

    b.write('}');
    return b.toString();
  }

  void _initWords(int nbits) {
    _words = new List<Int64>.filled(_wordIndex(nbits - 1) + 1, Int64.ZERO);
  }

  // Given a bit index, return word index containing it.
  static int _wordIndex(int bitIndex) {
    return bitIndex >> _ADDRESS_BITS_PER_WORD;
  }

  // Every public method must preserve these invariants.
  void _checkInvariants() {
    assert(_wordsInUse == 0 || _words[_wordsInUse - 1] != 0);
    assert(_wordsInUse >= 0 && _wordsInUse <= _words.length);
    assert(_wordsInUse == _words.length || _words[_wordsInUse] == 0);
  }

  // Sets the field wordsInUse to the logical size in words of the bit set.
  // WARNING:This method assumes that the number of words actually in use is
  // less than or equal to the current value of _wordsInUse!
  void _recalculateWordsInUse() {
    // Traverse the bitset until a used word is found
    int i;
    for (i = _wordsInUse - 1; i >= 0; i--)
      if (_words[i] != 0) break;
    _wordsInUse = i + 1; // The new logical size
  }

  // Ensures that the BitSet can hold enough words.
  // wordsRequired is the minimum acceptable number of words.
  void _ensureCapacity(int wordsRequired) {
    if (_words.length < wordsRequired) {
      // Allocate larger of doubled size or required size
      int request = max(2 * _words.length, wordsRequired);
      List<Int64> temp = new List<Int64>.filled(request, Int64.ZERO);
      temp.setRange(0, _words.length, _words);
      _words = temp;
      _sizeIsSticky = false;
    }
  }

  // Ensures that the BitSet can accommodate a given wordIndex,
  // temporarily violating the invariants.  The caller must
  // restore the invariants before returning to the user,
  // possibly using _recalculateWordsInUse().
  // wordIndex is the index to be accommodated.
  void _expandTo(int wordIndex) {
    int wordsRequired = wordIndex + 1;
    if (_wordsInUse < wordsRequired) {
      _ensureCapacity(wordsRequired);
      _wordsInUse = wordsRequired;
    }
  }

  // Checks that fromIndex ... toIndex is a valid range of bit indices.
  static void _checkRange(int fromIndex, int toIndex) {
    if (fromIndex < 0) throw new RangeError("fromIndex < 0: $fromIndex");
    if (toIndex < 0) throw new RangeError("toIndex < 0: $toIndex");
    if (fromIndex > toIndex)
      throw new RangeError("fromIndex: $fromIndex > toIndex: $toIndex");
  }

  static int _bitCount(Int64 i) {
    Int64 mask = Int64.parseHex("FFFFFFFFFFFFFFFF");
    Int64 mask1 = Int64.parseHex("3333333333333333");
    i = i - (((i & mask) >> 1) & Int64.parseHex("5555555555555555"));
    i = (i & mask1) + (((i & mask) >> 2) & mask1);
    i = (i + ((i & mask) >> 4)) & Int64.parseHex("0f0f0f0f0f0f0f0f");
    i = i + ((i & mask) >> 8);
    i = i + ((i & mask) >> 16);
    i = i + ((i & mask) >> 32);
    return (i & 0x7f).toInt();
  }
}
