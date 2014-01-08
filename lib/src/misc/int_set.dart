part of antlr4dart;

/**
 * A generic set of ints.
 */
abstract class IntSet {

  /**
   *  Return the size of this set (not the underlying implementation's
   *  allocated memory size, for example).
   */
  int get length;

  bool get isNil;

  bool operator==(Object obj);

  int get singleElement;

  /**
   *  Add an element to the set
   */
  void addSingle(int el);

  /**
   *  Add all elements from incoming set to this set.  Can limit
   *  to set of its own type. Return "this" so we can chain calls.
   */
  IntSet addAll(IntSet set);

  /**
   *  Return the intersection of this set with the argument, creating
   *  a new set.
   */
  IntSet and(IntSet a);

  IntSet complement(IntSet elements);

  IntSet or(IntSet a);

  IntSet subtract(IntSet a);

  bool contains(int el);

  /**
   * Remove this element from this set
   */
  void remove(int el);

  List<int> toList();

  String toString();
}
