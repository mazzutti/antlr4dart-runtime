part of antlr4dart;

/// A set of [int]s that relies on ranges being common to do
/// `run-length-encoded` like compression (if you view an [IntervalSet] like
/// a [BitSet] with runs of 0s and 1s). Only ranges are recorded so that
/// a few ints up near value 1000 don't cause massive bitsets, just two
/// int intervals.
///
/// Element values may be negative. Useful for sets of `EPSILON` and `EOF`.
///
/// `0..9` char range is index pair `['\u0030','\u0039']`.
/// Multiple ranges are encoded with multiple index pairs. Isolated elements
/// are encoded with an index pair where both intervals are the same.
///
/// The ranges are ordered and disjoint so that `2..6` appears
/// before `101..103`.
class IntervalSet {

  static final COMPLETE_CHAR_SET = IntervalSet.of(0, Lexer.MAX_CHAR_VALUE);
  static final EMPTY_SET = new IntervalSet();

  // The list of sorted, disjoint intervals.
  List<Interval> _intervals;

  bool isReadonly = false;

  IntervalSet([dynamic els]) {
    if (els == null) {
      _intervals = new List<Interval>();
    } else if (els is List<int>) {
      _intervals = new List<Interval>();
      els.forEach((e) => addSingle(e));
    } else {
      _intervals = els;
    }
  }

  IntervalSet.from(IntervalSet set) {
    _intervals = new List<Interval>();
    addAll(set);
  }

  /// Create a set with a single element [a].
  ///
  /// [a] could be an [int] or a single character [String].
  static IntervalSet ofSingle(dynamic a) => new IntervalSet([a]);

  /// Create a set with all ints within range `[a..b]` (inclusive).
  ///
  /// [a] and [b] could be [int]s or sigle character [String]s.
  static IntervalSet of(dynamic a, dynamic b) {
    if (a is String) a = a.codeUnitAt(0);
    if (b is String) b = b.codeUnitAt(0);
    IntervalSet intervalSet = new IntervalSet();
    intervalSet.add(a,b);
    return intervalSet;
  }

  /// Combine all sets in the list [sets].
  static IntervalSet combine(List<IntervalSet> sets) {
    IntervalSet intervalSet = new IntervalSet();
    sets.forEach((s) => intervalSet.addAll(s));
    return intervalSet;
  }

  int get length {
    int n = 0;
    int numIntervals = _intervals.length;
    if (numIntervals == 1) {
      Interval firstInterval = _intervals.first;
      return firstInterval._b - firstInterval._a + 1;
    }
    for (int i = 0; i < numIntervals; i++) {
      Interval _i = _intervals[i];
      n += (_i._b - _i._a + 1);
    }
    return n;
  }

  /// Return true if this set has no members.
  bool get isNil => _intervals.isEmpty;

  /// If this set is a single [int]? Return it, otherwise [Token.INVALID_TYPE].
  int get singleElement {
    if (_intervals.length == 1) {
      Interval i = _intervals.first;
      if (i._a == i._b ) return i._a;
    }
    return Token.INVALID_TYPE;
  }

  int get maxElement => (isNil) ? Token.INVALID_TYPE : _intervals.last._b;

  /// Return minimum element >= 0.
  int get minElement {
    if (isNil) return Token.INVALID_TYPE;
    int n = _intervals.length;
    for (Interval i in  _intervals) {
      int a = i._a;
      int b = i._b;
      for (int v = a; v <= b; v++) {
        if (v >= 0) return v;
      }
    }
    return Token.INVALID_TYPE;
  }

  /// Return a list of Interval objects.
  List<Interval> get intervals => _intervals;

  int get hashCode {
    int hash = MurmurHash.initialize();
    for (Interval i in _intervals) {
      hash = MurmurHash.update(hash, i._a);
      hash = MurmurHash.update(hash, i._b);
    }
    return MurmurHash.finish(hash, _intervals.length * 2);
  }

  /// Are two [IntervalSet]s equal?
  bool operator==(Object other) {
    if (other is IntervalSet) {
      if (_intervals.length == other._intervals.length) {
        for (int i = 0; i < _intervals.length; i++)
          if (_intervals[i] != other._intervals[i]) return false;
        return true;
      }
    }
    return false;
  }

  void clear() {
    if (isReadonly) throw new StateError("can't alter readonly IntervalSet");
    _intervals.clear();
  }

  /// Add a single element to the set. An isolated element is stored
  /// as a range `a..a`.
  ///
  /// [a] could be an [int] or a single character [String].
  void addSingle(dynamic a) {
    if (isReadonly) throw new StateError("can't alter readonly IntervalSet");
    add(a, a);
  }

  /// Add interval; i.e., add all integers from [a] to ][b] to set.
  ///
  /// If [b] < [a], do nothing.
  ///
  /// Keep list in sorted order (by left range value).
  ///
  /// If overlap, combine ranges. For example, if this is `{1..5, 10..20}`,
  /// adding `6..7` yields `{1..5, 6..7, 10..20}`. Adding `4..8` yields
  /// `{1..8, 10..20}`.
  ///
  /// [a] and [b] could be [int]s or single character [String]s.
  void add(dynamic a, dynamic b) {
    _add(Interval.of(a, b));
  }

  IntervalSet addAll(IntervalSet set) {
    if (set == null) return this;
    if (set is! IntervalSet) {
      throw new ArgumentError(
          "can't add non IntSet (${set.runtimeType}) to IntervalSet");
    }
    set._intervals.forEach((i) => add(i._a, i._b));
    return this;
  }

  /// Given the set of possible values, return a new set containing all
  /// elements in [vocabulary], but not in `this`.
  ///
  /// The computation is ([vocabulary] - `this`).
  ///
  /// 'this' is assumed to be either a subset or equal to [vocabulary].
  IntervalSet complement(IntervalSet vocabulary) {
    if (vocabulary == null) return null; // nothing in common with null set
    if (vocabulary is! IntervalSet) {
      throw new ArgumentError(
          "can't complement with non IntervalSet (${vocabulary.runtimeType})");
    }
    IntervalSet vocabularyCopy = new IntervalSet.from(vocabulary);
    int maxElement = vocabularyCopy.maxElement;
    IntervalSet compl = new IntervalSet();
    int n = _intervals.length;
    if (n == 0) return compl;
    Interval first = _intervals.first;
    // add a range from 0 to first.a constrained to vocab
    if (first._a > 0) {
      IntervalSet s = IntervalSet.of(0, first._a - 1);
      IntervalSet a = s.and(vocabularyCopy);
      compl.addAll(a);
    }
    for (int i = 1; i < n; i++) { // from 2nd interval .. nth
      Interval previous = _intervals[i - 1];
      Interval current = _intervals[i];
      IntervalSet s = IntervalSet.of(previous._b + 1, current._a - 1);
      IntervalSet a = s.and(vocabularyCopy);
      compl.addAll(a);
    }
    Interval last = intervals[n - 1];
    // add a range from last.b to maxElement constrained to vocab
    if (last._b < maxElement) {
      IntervalSet s = IntervalSet.of(last._b + 1, maxElement);
      IntervalSet a = s.and(vocabularyCopy);
      compl.addAll(a);
    }
    return compl;
  }

  /// Compute `this` - [other] via `this` & ~[other].
  ///
  /// Return a new set containing all elements in this but not in other.
  ///
  /// [other] is assumed to be a subset of `this`; anything that is in [other]
  /// but not in this will be ignored.
  IntervalSet subtract(IntervalSet other) {
    // assume the whole unicode range here for the complement
    // because it doesn't matter.  Anything beyond the max of this' set
    // will be ignored since we are doing this & ~other. The intersection
    // will be empty.  The only problem would be when this' set max value
    // goes beyond Lexer.MAX_CHAR_VALUE, but hopefully the constant
    // Lexer.MAX_CHAR_VALUE will prevent this.
    return and(other.complement(COMPLETE_CHAR_SET));
  }

  IntervalSet or(IntervalSet a) {
    return new IntervalSet()
        ..addAll(this)
        ..addAll(a);
  }

  /// Return a new set with the intersection of `this` set with [other].
  ///
  /// Because the intervals are sorted, we can use an iterator for each list
  /// and just walk them together. This is roughly `O(min(n,m))` for interval
  /// set lengths `n` and `m`.
  IntervalSet and(IntervalSet other) {
    if (other == null) return null; // nothing in common with null set
    List<Interval> theirIntervals = other._intervals;
    IntervalSet intersection = null;
    int mySize = _intervals.length;
    int theirSize = theirIntervals.length;
    int i = 0;
    int j = 0;
    // iterate down both interval lists looking for nondisjoint intervals
    while (i < mySize && j < theirSize) {
      Interval mine = _intervals[i];
      Interval theirs = theirIntervals[j];
      if (mine.startsBeforeDisjoint(theirs)) {
        // move this iterator looking for interval that might overlap
        i++;
      } else if (theirs.startsBeforeDisjoint(mine)) {
        // move other iterator looking for interval that might overlap
        j++;
      } else if (mine.properlyContains(theirs)) {
        // overlap, add intersection, get next theirs
        if (intersection == null) intersection = new IntervalSet();
        intersection._add(mine.intersection(theirs));
        j++;
      } else if (theirs.properlyContains(mine)) {
        // overlap, add intersection, get next mine
        if (intersection == null) intersection = new IntervalSet();
        intersection._add(mine.intersection(theirs));
        i++;
      } else if (!mine.disjoint(theirs)) {
        // overlap, add intersection
        if (intersection == null) intersection = new IntervalSet();
        intersection._add(mine.intersection(theirs));
        // Move the iterator of lower range [a..b], but not
        // the upper range as it may contain elements that will collide
        // with the next iterator. So, if mine=[0..115] and
        // theirs=[115..200], then intersection is 115 and move mine
        // but not theirs as theirs may collide with the next range
        // in thisIter.
        // move both iterators to next ranges
        if (mine.startsAfterNonDisjoint(theirs)) {
          j++;
        } else if (theirs.startsAfterNonDisjoint(mine)) {
          i++;
        }
      }
    }
    if (intersection == null) return new IntervalSet();
    return intersection;
  }

  /// Is [a] in any range of this set?
  ///
  /// [a] could be a [int] or a single character [String].
  bool contains(dynamic a) {
    if (a is String) a = a.codeUnitAt(0);
    for (Interval i in _intervals) {
      // list is sorted and el is before this interval; not here
      if (a < i._a) break;
      if (a >= i._a && a <= i._b) return true; // found in this interval
    }
    return false;
  }

  String toString([bool elemAreChar = false]) {
    StringBuffer sb = new StringBuffer();
    if (_intervals == null || _intervals.isEmpty) return "{}";
    if (length > 1) sb.write("{");
    Iterator<Interval> iter = _intervals.iterator;
    bool first = true;
    while (iter.moveNext()) {
      if (!first) sb.write(", ");
      else first = false;
      Interval i = iter.current;
      int a = i._a;
      int b = i._b;
      if (a == b) {
        if (a == -1) {
          sb.write("<EOF>");
        } else if (elemAreChar) {
          sb.write("'$a'");
        } else {
          sb.write(a);
        }
      } else {
        if (elemAreChar) {
          sb.write("'$a'..'$b'");
        } else {
          sb.write("$a..$b");
        }
      }
    }
    if (length > 1) sb.write("}");
    return sb.toString();
  }

  String toTokenString(List<String> tokenNames) {
    StringBuffer sb = new StringBuffer();
    if (_intervals == null || _intervals.isEmpty) return "{}";
    if (length > 1) sb.write("{");
    Iterator<Interval> iter = _intervals.iterator;
    bool first = true;
    while (iter.moveNext()) {
      if (!first) {
        sb.write(", ");
      } else {
        first = false;
      }
      Interval I = iter.current;
      int a = I._a;
      int b = I._b;
      if (a == b) {
        sb.write(_elementName(tokenNames, a));
      } else {
        for (int i=a; i<=b; i++) {
          if (i > a) sb.write(", ");
          sb.write(_elementName(tokenNames, i));
        }
      }
    }
    if (length > 1) {
      sb.write("}");
    }
    return sb.toString();
  }

  List<int> toList() {
    List<int> values = new List<int>();
    int n = _intervals.length;
    for (Interval i in _intervals) {
      for (int v = i._a; v <= i._b; v++) {
        values.add(v);
      }
    }
    return values;
  }

  Set<int> toSet() {
    Set<int> set = new HashSet<int>();
    for (Interval i in _intervals) {
      for (int v = i._a; v <= i._b; v++) {
        set.add(v);
      }
    }
    return set;
  }

  void remove(dynamic a) {
    if (isReadonly) throw new StateError("can't alter readonly IntervalSet");
    if (a is String) a = a.codeUnitAt(0);
    int n = _intervals.length;
    for (int i = 0; i < n; i++) {
      Interval interval = _intervals[i];
      // list is sorted and el is before this interval; not here
      if (a < interval._a) break;
      // if whole interval x..x, rm
      if (a == interval._a && a == interval._b) {
        _intervals.removeAt(i);
        break;
      }
      // if on left edge x..b, adjust left
      if (a == interval._a) {
        interval._a++;
        break;
      }
      // if on right edge a..x, adjust right
      if (a == interval._b) {
        interval._b--;
        break;
      }
      // if in middle a..x..b, split interval
      if (a > interval._a && a < interval._b) {
        // found in this interval
        int oldb = interval._b;
        interval._b = a - 1; // [a..x-1]
        add(a + 1, oldb);    // add [x+1..b]
      }
    }
  }

  // copy on write so we can cache a..a intervals and sets of that
  void _add(Interval addition) {
    if (isReadonly) throw new StateError("can't alter readonly IntervalSet");
    if (addition._b < addition._a) return;
    // find position in list
    // Use iterators as we modify list in place
    for (int i = 0; i < _intervals.length; i++) {
      Interval r = _intervals[i];
      if (addition == r) return;
      if (addition.adjacent(r) || !addition.disjoint(r)) {
        // next to each other, make a single larger interval
        Interval bigger = addition.union(r);
        _intervals[i] = bigger;
        // make sure we didn't just create an interval that
        // should be merged with next interval in list
        while (i < _intervals.length - 1) {
          Interval next = _intervals[++i];
          if (!bigger.adjacent(next) && bigger.disjoint(next)) break;
          _intervals.remove(next); // remove this one
          _intervals[--i] = bigger.union(next); // set to 3 merged ones
        }
        return;
      }
      if (addition.startsBeforeDisjoint(r)) {
        // insert before r
        _intervals.insert(i, addition);
        return;
      }
      // if disjoint and after r, a future iteration will handle it
    }
    // ok, must be after last interval (and disjoint from last interval)
    // just add it
    _intervals.add(addition);
  }

  String _elementName(List<String> tokenNames, int a) {
    if (a == Token.EOF) {
      return "<EOF>";
    } else if (a == Token.EPSILON) {
      return "<EPSILON>";
    }
    return tokenNames[a];
  }
}
