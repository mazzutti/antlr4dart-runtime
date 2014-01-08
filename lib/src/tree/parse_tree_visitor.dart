part of antlr4dart;

/**
 * This interface defines the basic notion of a parse tree visitor. Generated
 * visitors implement this interface and the `XVisitor` interface for
 * grammar `X`.
 *
 * [T] is the return type of the visit operation. Use `void` for
 * operations with no return type.
 */
abstract class ParseTreeVisitor<T> {

  /**
   * Visit a parse tree, and return a user-defined result of the operation.
   *
   * [tree] is the [ParseTree] to visit.
   * Return The result of visiting the parse tree.
   */
  T visit(ParseTree tree);

  /**
   * Visit the children of a node, and return a user-defined result of the
   * operation.
   *
   * [node] is the [RuleNode] whose children should be visited.
   * Return the result of visiting the children of the node.
   */
  T visitChildren(RuleNode node);

  /**
   * Visit a terminal node, and return a user-defined result of the operation.
   *
   * [node] is the [TerminalNode] to visit.
   * Return the result of visiting the node.
   */
  T visitTerminal(TerminalNode node);

  /**
   * Visit an error node, and return a user-defined result of the operation.
   *
   * [node] is the [ErrorNode] to visit.
   * Return The result of visiting the node.
   */
  T visitErrorNode(ErrorNode node);
}
