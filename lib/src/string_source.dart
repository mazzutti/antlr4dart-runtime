part of antlr4dart;

class StringSource implements CharSource {

  // The data being scanned
  List<int> _data;

  // 0..n-1 index into string of next char
  int _p = 0;

  /// Line number 1..n within the input.
  int line = 1;

  /// What is name or source?
  String name;

  /// Copy data in string to a local int list.
  StringSource(String input) {
    _data = input.codeUnits;
  }

  /// Reset the source so that it's in the same state it was
  /// when the object was created *except* the data array is not
  /// touched.
  void reset() {
    _p = 0;
  }

  void consume() {
    if (_p >= _data.length) {
      assert(lookAhead(1) == IntSource.EOF);
      throw new StateError("cannot consume EOF");
    }
    _p++;
  }

  int lookAhead(int i) {
    if (i == 0) return 0; // undefined
    if (i < 0) {
      i++; // e.g., translate lookAhead(-1) to use offset i=0; then data[p+0-1]
      if ((_p + i - 1) < 0) return IntSource.EOF; // invalid; no char before first char
    }
    if ((_p + i - 1) >= _data.length) return IntSource.EOF;
    return _data[_p + i - 1];
  }

  int lookToken(int i) => lookAhead(i);

  /// Return the current input symbol index 0..n where n indicates the
  /// last symbol has been read.  The index is the index of char to
  /// be returned from lookAhead(1).
  int get index => _p;

  int get length => _data.length;

  /// mark/release do nothing; we have entire buffer.
  int get mark => -1;

  void release(int marker) {}

  void seek(int index) {
    if (index <= _p) {
      _p = index; // just jump; don't update source state (line, ...)
      return;
    }
    // seek forward, consume until p hits index or n (whichever comes first)
    index = min(index, _data.length);
    while (_p < index) {
      consume();
    }
  }

  String getText(Interval interval) {
    int start = interval.a;
    int stop = interval.b;
    if (stop >= _data.length) stop = _data.length - 1;
    int count = stop - start + 1;
    if (start >= _data.length) return "";
    return new String.fromCharCodes(_data.getRange(start, start + count));
  }

  String get sourceName => name;

  String toString() => new String.fromCharCodes(_data);
}
