part of antlr4dart;

/**
 *  An immutable inclusive interval a..b
 */
class Interval {

  static const int INTERVAL_POOL_MAX_VALUE = 1000;

  static final Interval INVALID = new Interval(-1,-2);

  static List<Interval> cache = new List<Interval>(INTERVAL_POOL_MAX_VALUE + 1);

  static int creates = 0;
  static int misses = 0;
  static int hits = 0;
  static int outOfRange = 0;

  int a;
  int b;

  Interval(this.a, this.b);

  /**
   *  Interval objects are used readonly so share all with the
   *  same single value a == b up to some max size.  Use an array as a perfect hash.
   *  Return shared object for 0..INTERVAL_POOL_MAX_VALUE or a new
   *  Interval object with a..a in it.
   *  `a` and `b` could be both ints or single character Strings.
   */
  static Interval of(dynamic a, dynamic b) {
    if (a is String) a = a.codeUnitAt(0);
    if (b is String) b = b.codeUnitAt(0);
    // cache just a..a
    if (a != b || a < 0 || a > INTERVAL_POOL_MAX_VALUE) {
      return new Interval(a, b);
    }
    if (cache[a] == null) {
      cache[a] = new Interval(a, a);
    }
    return cache[a];
  }

  /**
   *  Return number of elements between a and b inclusively. x..x is length 1.
   *  if b < a, then length is 0. 9..10 has length 2.
   */
  int get length => (b < a) ? 0 : b - a + 1;

  bool operator==(Interval o) => a == o.a && b == o.b;

  /**
   *  Does this start completely before other? Disjoint
   */
  bool startsBeforeDisjoint(Interval other) => a < other.a && b < other.a;

  /**
   *  Does this start at or before other? Nondisjoint
   */
  bool startsBeforeNonDisjoint(Interval other) => a <= other.a && b >= other.a;

  /**
   *  Does this.a start after other.b? May or may not be disjoint
   */
  bool startsAfter(Interval other) => a > other.a;

  /**
   *  Does this start completely after other? Disjoint
   */
  bool startsAfterDisjoint(Interval other) => a > other.b;

  /**
   *  Does this start after other? NonDisjoint
   */
  bool startsAfterNonDisjoint(Interval other) => a > other.a && a <= other.b;

  /**
   *  Are both ranges disjoint? I.e., no overlap?
   */
  bool disjoint(Interval other) {
    return startsBeforeDisjoint(other) || startsAfterDisjoint(other);
  }

  /**
   *  Are two intervals adjacent such as 0..41 and 42..42?
   */
  bool adjacent(Interval other) => a == other.b + 1 || b == other.a - 1;

  bool properlyContains(Interval other) => other.a >= a && other.b <= b;

  /**
   *  Return the interval computed from combining this and [other].
   */
  Interval union(Interval other) {
    return Interval.of(min(a, other.a), max(b, other.b));
  }

  /**
   *  Return the interval in common between this and [other].
   */
  Interval intersection(Interval other) {
    return Interval.of(max(a, other.a), min(b, other.b));
  }

  /**
   *  Return the interval with elements from this not in [other];
   *  [other] must not be totally enclosed (properly contained)
   *  within this, which would result in two disjoint intervals
   *  instead of the single one returned by this method.
   */
  Interval differenceNotProperlyContained(Interval other) {
    Interval diff = null;
    if (other.startsBeforeNonDisjoint(this)) {
      // other.a to left of this.a (or same)
      diff = Interval.of(max(this.a, other.b + 1), this.b);
    } else if (other.startsAfterNonDisjoint(this)) {
      // other.a to right of this.a
      diff = Interval.of(this.a, other.a - 1);
    }
    return diff;
  }

  String toString() => "$a..$b";
}
