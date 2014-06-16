part of antlr4dart;

/// Sometimes we need to map a key to a value but key is two pieces of data.
class DoubleKeyMap<Key1, Key2, Value> {

  Map<Key1, Map<Key2, Value>> data;

  DoubleKeyMap() {
    data = new LinkedHashMap<Key1, Map<Key2, Value>>();
  }

  Iterable<Value> get values {
    Set<Value> set = new HashSet<Value>();
    for (Map<Key2, Value> key in data.values)
      for (Value value in key.values) set.add(value);
    return set;
  }

  Set get keys => data.keys;

  Value put(Key1 key1, Key2 key2, Value value) {
    Map<Key2, Value> data = this.data[key1];
    Value prev = null;
    if (data == null) {
      data = new LinkedHashMap<Key2, Value>();
      this.data[key1] =  data;
    } else {
      prev = data[key2];
    }
    data[key2] = value;
    return prev;
  }

  Value get(Key1 key1, Key2 key2) {
    Map<Key2, Value> data = this.data[key1];
    if (data == null) return null;
    return data[key2];
  }

  Map<Key2, Value> operator [](Key1 key) => data[key];

  /// Get all values associated with primary [key].
  Iterable<Value> valuesForKey(Key1 key) {
    Map<Key2, Value> data = this.data[key];
    if (data == null) return null;
    return data.values;
  }

  Set keySetForKey(Key1 key) {
    Map<Key2, Value> data = this.data[key];
    if (data == null) return null;
    return data.keys;
  }
}

