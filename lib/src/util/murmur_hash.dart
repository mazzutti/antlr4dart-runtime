part of antlr4dart;

class MurmurHash {

  static const int DEFAULT_SEED = 0;

  const MurmurHash._internal();

  /// Initialize the hash using the specified [seed].
  ///
  /// Return the intermediate hash value.
  static int initialize([int seed = DEFAULT_SEED]) => seed;

  /// Update the intermediate hash value for the next input [value].
  ///
  /// [hash] is the intermediate hash value.
  /// [value] the value to add to the current hash.
  ///
  /// Return the updated intermediate hash value.
  static int update(int hash, [int value]) {
    value = value != null ? value.hashCode : 0;
    final int c1 = 0xCC9E2D51;
    final int c2 = 0x1B873593;
    final int r1 = 15;
    final int r2 = 13;
    final int m = 5;
    final int n = 0xE6546B64;
    int k = value;
    k = k * c1;
    k = (k << r1) | ((k & 0xFFFFFFFF) >> (32 - r1));
    k = k * c2;
    hash = hash ^ k;
    hash = (hash << r2) | ((hash & 0xFFFFFFFF) >> (32 - r2));
    hash = hash * m + n;
    return hash & 0xFFFFFFFFFFFFFF;
  }

  /// Apply the final computation steps to the intermediate value [hash]
  /// to form the final result of the MurmurHash 3 hash function.
  ///
  /// [hash] is the intermediate hash value.
  /// [numberOfWords] is the number of integer values added to the hash.
  ///
  /// Return the final hash result.
  static int finish(int hash, int numberOfWords) {
    hash = hash ^ (numberOfWords * 4);
    hash = hash ^ ((hash & 0xFFFFFFFF) >> 16);
    hash = hash * 0x85EBCA6B;
    hash = hash ^ ((hash & 0xFFFFFFFF) >> 13);
    hash = hash * 0xC2B2AE35;
    hash = hash ^ ((hash & 0xFFFFFFFF) >> 16);
    return hash & 0xFFFFFFFF;
  }

  /// Utility function to compute the hash code of an array using the
  /// MurmurHash algorithm.
  ///
  /// [data] is the iterable data.
  /// [seed] is the seed for the MurmurHash algorithm.
  ///
  /// Return the hash code of the data.
  static int calcHashCode(Iterable<SemanticContext> data, int seed) {
    int hash = initialize(seed);
    for (var value in data) {
      hash = update(hash, value.hashCode);
    }
    return finish(hash, data.length) & 0xFFFFFFFFF;
  }
}
