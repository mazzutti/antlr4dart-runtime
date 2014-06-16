part of antlr4dart;

/// An immutable inclusive interval `a..b`.
class Interval {

  static const int INTERVAL_POOL_MAX_VALUE = 1000;

  static final Interval INVALID = new Interval(-1,-2);

  static List<Interval> cache = new List<Interval>(INTERVAL_POOL_MAX_VALUE + 1);

  static int creates = 0;
  static int misses = 0;
  static int hits = 0;
  static int outOfRange = 0;

  int _a;
  int _b;

  Interval(this._a, this._b);

  /// Return number of elements between a and b inclusively. `x..x` is length 1.
  /// If `b < a`, then length is 0. For example 9..10 has length 2.
  int get length => (_b < _a) ? 0 : _b - _a + 1;

  /// [Interval] objects are used readonly so share all with the same single
  /// value a == b up to some max size. Use a list as a perfect hash.
  ///
  /// [a] and [b] could be both [int]s or single character [String]s.
  ///
  /// Return a shared object for `0..INTERVAL_POOL_MAX_VALUE` or a new [Interval]
  /// object with `a..a` in it.
  static Interval of(dynamic a, dynamic b) {
    if (a is String) a = a.codeUnitAt(0);
    if (b is String) b = b.codeUnitAt(0);
    // cache just a..a
    if (a != b || a < 0 || a > INTERVAL_POOL_MAX_VALUE) {
      return new Interval(a, b);
    }
    if (cache[a] == null) cache[a] = new Interval(a, a);
    return cache[a];
  }

  bool operator==(Interval o) => _a == o._a && _b == o._b;

  /// Does this start completely before other? Disjoint.
  bool startsBeforeDisjoint(Interval other) => _a < other._a && _b < other._a;

  /// Does this start at or before other? Nondisjoint.
  bool startsBeforeNonDisjoint(Interval other)
    => _a <= other._a && _b >= other._a;

  /// Does this.a start after other.b? May or may not be disjoint.
  bool startsAfter(Interval other) => _a > other._a;

  /// Does this start completely after other? Disjoint.
  bool startsAfterDisjoint(Interval other) => _a > other._b;

  /// Does this start after other? NonDisjoint.
  bool startsAfterNonDisjoint(Interval other)
    => _a > other._a && _a <= other._b;

  /// Are both ranges disjoint? I.e., no overlap?
  bool disjoint(Interval other)
    => startsBeforeDisjoint(other) || startsAfterDisjoint(other);

  /// Are two intervals adjacent such as 0..41 and 42..42?
  bool adjacent(Interval other) => _a == other._b + 1 || _b == other._a - 1;

  bool properlyContains(Interval other) => other._a >= _a && other._b <= _b;

  /// Return the interval computed from combining this and [other].
  Interval union(Interval other)
    => Interval.of(min(_a, other._a), max(_b, other._b));

  /// Return the interval in common between this and [other].
  Interval intersection(Interval other)
    => Interval.of(max(_a, other._a), min(_b, other._b));

  /// Return the interval with elements from this not in [other].
  ///
  /// [other] must not be totally enclosed (properly contained) within this,
  /// which would result in two disjoint intervals instead of the single one
  /// returned by this method.
  Interval differenceNotProperlyContained(Interval other) {
    Interval diff = null;
    if (other.startsBeforeNonDisjoint(this)) {
      // other.a to left of this.a (or same)
      diff = Interval.of(max(_a, other._b + 1), _b);
    } else if (other.startsAfterNonDisjoint(this)) {
      // other.a to right of this.a
      diff = Interval.of(_a, other._a - 1);
    }
    return diff;
  }

  String toString() => "$_a..$_b";
}
