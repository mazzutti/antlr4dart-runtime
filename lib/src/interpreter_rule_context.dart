part of antlr4dart;

/// This object is used by the [ParserInterpreter] and is the same as a regular
/// [ParserRuleContext] except that we need to track the rule index of the
/// current context so that we can build parse trees.
class InterpreterRuleContext extends ParserRuleContext {
  final int ruleIndex;

  InterpreterRuleContext(ParserRuleContext parent,
                         int invokingStateNumber,
                         this.ruleIndex) : super(parent, invokingStateNumber);

}