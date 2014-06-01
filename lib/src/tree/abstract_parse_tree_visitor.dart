part of antlr4dart;

abstract class AbstractParseTreeVisitor<T> implements ParseTreeVisitor<T> {

  /// The default implementation calls [ParseTree.accept] on the
  /// specified tree.
  T visit(ParseTree tree) => tree.accept(this);

  /// The default implementation initializes the aggregate result to
  /// [defaultResult]`()`. Before visiting each child, it calls
  /// [shouldVisitNextChild]`()`; if the result is `false}` no more
  /// children are visited and the current aggregate result is returned.
  /// After visiting a child, the aggregate result is updated by calling
  /// [aggregateResult]`()` with the previous aggregate result and the
  /// result of visiting the child.
  T visitChildren(RuleNode node) {
    T result = defaultResult();
    int n = node.childCount;
    for (int i = 0; i < n; i++) {
      if (!shouldVisitNextChild(node, result)) {
        break;
      }
      ParseTree c = node.getChild(i);
      T childResult = c.accept(this);
      result = aggregateResult(result, childResult);
    }
    return result;
  }

  /// The default implementation returns the result of
  /// [defaultResult]`()`.
  T visitTerminal(TerminalNode node) => defaultResult();

  /// The default implementation returns the result of
  /// [defaultResult]`()`.
  T visitErrorNode(ErrorNode node) => defaultResult();

  /// Gets the default value returned by visitor methods. This value is
  /// returned by the default implementations of [visitTerminal]`()`,
  /// [visitErrorNode]`()`. The default implementation of [visitChildren]`()`
  /// initializes its aggregate result to this value.
  ///
  /// The base implementation returns `null`.
  ///
  /// Return the default value returned by visitor methods.
  T defaultResult() => null;

  /// Aggregates the results of visiting multiple children of a node. After
  /// either all children are visited or [shouldVisitNextChild]`()` returns
  /// `false`, the aggregate value is returned as the result of [visitChildren]`()`.
  ///
  /// The default implementation returns [nextResult], meaning
  /// [visitChildren]`()` will return the result of the last child visited
  /// (or return the initial value if the node has no children).
  ///
  /// [aggregate] is the previous aggregate value. In the default
  /// implementation, the aggregate value is initialized to [defaultResult]`()`,
  /// which is passed as the [aggregate] argument to this method after the
  /// first child node is visited.
  /// [nextResult] is the result of the immediately preceeding call to visit
  /// a child node.
  ///
  /// Return the updated aggregate result.
  T aggregateResult(T aggregate, T nextResult) => nextResult;

  /// This method is called after visiting each child in [visitChildren]`()`.
  /// This method is first called before the first child is visited; at that
  /// point [currentResult] will be the initial value (in the default
  /// implementation, the initial value is returned by a call to [defaultResult]`()`.
  /// This method is not called after the last child is visited.
  ///
  /// The default implementation always returns `true`, indicating that
  /// [visitChildren]`()` should only return after all children are visited.
  /// One reason to override this method is to provide a "short circuit"
  /// evaluation option for situations where the result of visiting a single
  /// child has the potential to determine the result of the visit operation as
  /// a whole.
  ///
  /// [node] is the [RuleNode] whose children are currently being visited.
  /// [currentResult] is the current aggregate result of the children visited
  /// to the current point.
  ///
  /// Return `true` to continue visiting children. Otherwise return
  /// `false` to stop visiting children and immediately return the
  /// current aggregate result from [visitChildren]`()`.
  bool shouldVisitNextChild(RuleNode node, T currentResult) => true;
}