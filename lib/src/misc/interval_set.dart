part of antlr4dart;

///  A set of integers that relies on ranges being common to do
///  "run-length-encoded" like compression (if you view an [IntSet] like
///  a [BitSet] with runs of 0s and 1s).  Only ranges are recorded so that
///  a few ints up near value 1000 don't cause massive bitsets, just two
///  integer intervals.
///
///  element values may be negative.  Useful for sets of EPSILON and EOF.
///
///  0..9 char range is index pair ['\u0030','\u0039'].
///  Multiple ranges are encoded with multiple index pairs.  Isolated
///  elements are encoded with an index pair where both intervals are the same.
///
///  The ranges are ordered and disjoint so that 2..6 appears before 101..103.
class IntervalSet implements IntSet {

  static final IntervalSet COMPLETE_CHAR_SET = IntervalSet.of(0, Lexer.MAX_CHAR_VALUE);
  static final IntervalSet EMPTY_SET = new IntervalSet();

  /// Create a set with a single element, `el`.
  /// `el` could be an int or a single character string.
  static IntervalSet ofSingle(dynamic a) => new IntervalSet([a]);

  /// Create a set with all ints within range `[a..b]` (inclusive).
  /// `a` and `b` could be ints or sigle character strings.
  static IntervalSet of(dynamic a, dynamic b) {
    if (a is String) a = a.codeUnitAt(0);
    if (b is String) b = b.codeUnitAt(0);
    IntervalSet s = new IntervalSet();
    s.add(a,b);
    return s;
  }

  /// Combine all sets in the list returned the or'd value.
  static IntervalSet combine(List<IntervalSet> sets) {
    IntervalSet r = new IntervalSet();
    sets.forEach((s) => r.addAll(s));
    return r;
  }

  /// The list of sorted, disjoint intervals.
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

  int get length {
    int n = 0;
    int numIntervals = _intervals.length;
    if (numIntervals == 1) {
      Interval firstInterval = _intervals.first;
      return firstInterval.b - firstInterval.a + 1;
    }
    for (int i = 0; i < numIntervals; i++) {
      Interval _i = _intervals[i];
      n += (_i.b - _i.a + 1);
    }
    return n;
  }

  /// return true if this set has no members
  bool get isNil => _intervals.isEmpty;

  ///  If this set is a single int, return
  ///  it otherwise Token.INVALID_TYPE.
  int get singleElement {
    if (_intervals.length == 1) {
      Interval i = _intervals.first;
      if (i.a == i.b ) return i.a;
    }
    return Token.INVALID_TYPE;
  }

  int get maxElement {
    if (isNil) return Token.INVALID_TYPE;
    return _intervals.last.b;
  }

  ///  Return minimum element >= 0
  int get minElement {
    if (isNil) return Token.INVALID_TYPE;
    int n = _intervals.length;
    for (Interval i in  _intervals) {
      int a = i.a;
      int b = i.b;
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
      hash = MurmurHash.update(hash, i.a);
      hash = MurmurHash.update(hash, i.b);
    }
    hash = MurmurHash.finish(hash, _intervals.length * 2);
    return hash;
  }

  ///  Are two IntervalSets equal?
  bool operator==(Object obj) {
    if (obj is IntervalSet) {
      if (_intervals.length == obj._intervals.length) {
        for (int i = 0; i < _intervals.length; i++)
          if (_intervals[i] != obj._intervals[i]) return false;
        return true;
      }
    }
    return false;
  }

  void clear() {
    if (isReadonly) throw new StateError("can't alter readonly IntervalSet");
    _intervals.clear();
  }

  ///  Add a single element to the set.  An isolated element is stored
  ///  as a range el..el.
  ///  `el` could be an int or a single character string.
  void addSingle(dynamic el) {
    if (isReadonly) throw new StateError("can't alter readonly IntervalSet");
    add(el, el);
  }

  ///  Add interval; i.e., add all integers from a to b to set.
  ///  If b < a, do nothing.
  ///  Keep list in sorted order (by left range value).
  ///  If overlap, combine ranges.  For example,
  ///  If this is {1..5, 10..20}, adding 6..7 yields
  ///  {1..5, 6..7, 10..20}.  Adding 4..8 yields {1..8, 10..20}.
  ///  `a` and `b` could be ints or single character strings.
  void add(dynamic a, dynamic b) {
    _add(Interval.of(a, b));
  }

  IntervalSet addAll(IntSet set) {
    if (set == null) return this;
    if (set is! IntervalSet) {
      throw new ArgumentError(
          "can't add non IntSet (${set.runtimeType}) to IntervalSet");
    }
    (set as IntervalSet)._intervals.forEach((i) => add(i.a, i.b));
    return this;
  }

  ///  Given the set of possible values (rather than, say UNICODE or MAXINT),
  ///  return a new set containing all elements in vocabulary, but not in
  ///  this.  The computation is (vocabulary - this).
  ///
  ///  'this' is assumed to be either a subset or equal to vocabulary.
  IntervalSet complement(IntSet vocabulary) {
    if (vocabulary == null) return null; // nothing in common with null set
    if (vocabulary is! IntervalSet) {
      throw new ArgumentError(
          "can't complement with non IntervalSet (${vocabulary.runtimeType})");
    }
    IntervalSet vocabularyIS = vocabulary;
    int maxElement = vocabularyIS.maxElement;
    IntervalSet compl = new IntervalSet();
    int n = _intervals.length;
    if (n == 0) return compl;
    Interval first = _intervals.first;
    // add a range from 0 to first.a constrained to vocab
    if (first.a > 0) {
      IntervalSet s = IntervalSet.of(0, first.a - 1);
      IntervalSet a = s.and(vocabularyIS);
      compl.addAll(a);
    }
    for (int i=1; i<n; i++) { // from 2nd interval .. nth
      Interval previous = _intervals[i - 1];
      Interval current = _intervals[i];
      IntervalSet s = IntervalSet.of(previous.b + 1, current.a - 1);
      IntervalSet a = s.and(vocabularyIS);
      compl.addAll(a);
    }
    Interval last = intervals[n - 1];
    // add a range from last.b to maxElement constrained to vocab
    if (last.b < maxElement) {
      IntervalSet s = IntervalSet.of(last.b + 1, maxElement);
      IntervalSet a = s.and(vocabularyIS);
      compl.addAll(a);
    }
    return compl;
  }

  ///  Compute this - other via this & ~other.
  ///
  ///  Return a new set containing all elements in this but not in other.
  ///  other is assumed to be a subset of this;
  ///  anything that is in other but not in this will be ignored.
  IntervalSet subtract(IntSet other) {
    // assume the whole unicode range here for the complement
    // because it doesn't matter.  Anything beyond the max of this' set
    // will be ignored since we are doing this & ~other. The intersection
    // will be empty.  The only problem would be when this' set max value
    // goes beyond Lexer.MAX_CHAR_VALUE, but hopefully the constant
    // Lexer.MAX_CHAR_VALUE will prevent this.
    return this.and(other.complement(COMPLETE_CHAR_SET));
  }

  IntervalSet or(IntSet a) {
    IntervalSet o = new IntervalSet();
    o.addAll(this);
    o.addAll(a);
    return o;
  }

  ///  Return a new set with the intersection of this set with other.  Because
  ///  the intervals are sorted, we can use an iterator for each list and
  ///  just walk them together.  This is roughly O(min(n,m)) for interval
  ///  list lengths n and m.
  IntervalSet and(IntSet other) {
    if (other == null) return null; // nothing in common with null set
    List<Interval> theirIntervals = (other as IntervalSet)._intervals;
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

  ///  Is el in any range of this set?
  ///  `el` could be a int or a single character string.
  bool contains(dynamic el) {
    if (el is String) el = el.codeUnitAt(0);
    int n = _intervals.length;
    for (Interval i in _intervals) {
      int a = i.a;
      int b = i.b;
      // list is sorted and el is before this interval; not here
      if (el < a) break;
      if (el >= a && el <= b) return true; // found in this interval
    }
    return false;
  }

  String toString([bool elemAreChar = false]) {
    StringBuffer buf = new StringBuffer();
    if (_intervals == null || _intervals.isEmpty) {
      return "{}";
    }
    if (length > 1) buf.write("{");
    Iterator<Interval> iter = _intervals.iterator;
    bool first = true;
    while (iter.moveNext()) {
      if (!first) buf.write(", ");
      else first = false;
      Interval i = iter.current;
      int a = i.a;
      int b = i.b;
      if (a == b) {
        if (a == -1) buf.write("<EOF>");
        else if (elemAreChar) buf..write("'$a'");
        else buf.write(a);
      } else {
        if (elemAreChar) buf..write("'$a'..'$b'");
        else buf.write("$a..$b");
      }
    }
    if (length > 1) buf.write("}");
    return buf.toString();
  }

  String toTokenString(List<String> tokenNames) {
    StringBuffer buf = new StringBuffer();
    if (_intervals == null || _intervals.isEmpty) {
      return "{}";
    }
    if (length > 1) buf.write("{");
    Iterator<Interval> iter = _intervals.iterator;
    bool first = true;
    while (iter.moveNext()) {
      if (!first) buf.write(", ");
      else first = false;
      Interval I = iter.current;
      int a = I.a;
      int b = I.b;
      if (a == b) {
        buf.write(_elementName(tokenNames, a));
      } else {
        for (int i=a; i<=b; i++) {
          if (i > a) buf.write(", ");
          buf.write(_elementName(tokenNames, i));
        }
      }
    }
    if (length > 1) {
      buf.write("}");
    }
    return buf.toString();
  }

  List<int> toList() {
    List<int> values = new List<int>();
    int n = _intervals.length;
    for (Interval i in _intervals) {
      int a = i.a;
      int b = i.b;
      for (int v = a; v <= b; v++) {
        values.add(v);
      }
    }
    return values;
  }

  Set<int> toSet() {
    Set<int> s = new HashSet<int>();
    for (Interval i in _intervals) {
      int a = i.a;
      int b = i.b;
      for (int v = a; v <= b; v++) {
        s.add(v);
      }
    }
    return s;
  }

  void remove(dynamic el) {
    if (isReadonly) throw new StateError("can't alter readonly IntervalSet");
    if (el is String) el = el.codeUnitAt(0);
    int n = _intervals.length;
    for (int i = 0; i < n; i++) {
      Interval _i = _intervals[i];
      int a = _i.a;
      int b = _i.b;
      // list is sorted and el is before this interval; not here
      if (el < a) break;
      // if whole interval x..x, rm
      if (el == a && el == b) {
        _intervals.removeAt(i);
        break;
      }
      // if on left edge x..b, adjust left
      if (el == a) {
        _i.a++;
        break;
      }
      // if on right edge a..x, adjust right
      if (el == b) {
        _i.b--;
        break;
      }
      // if in middle a..x..b, split interval
      if (el > a && el < b) {
        // found in this interval
        int oldb = _i.b;
        _i.b = el-1;     // [a..x-1]
        add(el + 1, oldb); // add [x+1..b]
      }
    }
  }

  // copy on write so we can cache a..a intervals and sets of that
  void _add(Interval addition) {
    if (isReadonly) throw new StateError("can't alter readonly IntervalSet");
    if (addition.b < addition.a) return;
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
    // ok, must be after last interval (and disjoint from last interval) just add it
    _intervals.add(addition);
  }

  String _elementName(List<String> tokenNames, int a) {
    if (a == Token.EOF) return "<EOF>";
    else if (a == Token.EPSILON) return "<EPSILON>";
    return tokenNames[a];
  }
}
