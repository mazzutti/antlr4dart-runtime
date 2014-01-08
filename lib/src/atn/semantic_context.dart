part of antlr4dart;

/**
 * A tree structure used to record the semantic context in which
 * an ATN configuration is valid.  It's either a single predicate,
 * a conjunction `p1 && p2`, or a sum of products `p1 || p2`.
 */
abstract class SemanticContext {

  static final SemanticContext NONE = new Predicate();

  SemanticContext parent;

  /**
   * For context independent predicates, we evaluate them without a local
   * context (i.e., null context). That way, we can evaluate them without
   * having to create proper rule-specific context during prediction (as
   * opposed to the parser, which creates them naturally). In a practical
   * sense, this avoids a cast error from [RuleContext] to myruleContext.
   *
   * For context dependent predicates, we must pass in a local context so that
   * references such as `$arg` evaluate properly as `_localctx.arg`. We only
   * capture context dependent predicates in the context in which we begin
   * prediction, so we passed in the outer context here in case of context
   * dependent predicate evaluation.
   */
  bool eval(Recognizer parser, RuleContext outerContext);

  static SemanticContext and(SemanticContext a, SemanticContext b) {
    if (a == null || a == NONE) return b;
    if (b == null || b == NONE) return a;
    And result = new And(a, b);
    if (result.opnds.length == 1) {
      return result.opnds[0];
    }
    return result;
  }

  /**
   *  See [ParserATNSimulator.predsForAmbigAlts]
   */
  static SemanticContext or(SemanticContext a, SemanticContext b) {
    if (a == null) return b;
    if (b == null) return a;
    if (a == NONE || b == NONE) return NONE;
    Or result = new Or(a, b);
    if (result.opnds.length == 1) {
      return result.opnds[0];
    }
    return result;
  }
}

class Predicate extends SemanticContext {
  final int ruleIndex;
  final int predIndex;
  final bool isCtxDependent;

  Predicate([this.ruleIndex = -1,
             this.predIndex = -1,
             this.isCtxDependent = false]);

  bool eval(Recognizer parser, RuleContext outerContext) {
    RuleContext localctx = isCtxDependent ? outerContext : null;
    return parser.sempred(localctx, ruleIndex, predIndex);
  }

  int get hashCode {
    int hashCode = MurmurHash.initialize();
    hashCode = MurmurHash.update(hashCode, ruleIndex);
    hashCode = MurmurHash.update(hashCode, predIndex);
    hashCode = MurmurHash.update(hashCode, isCtxDependent ? 1 : 0);
    hashCode = MurmurHash.finish(hashCode, 3);
    return hashCode;
  }

  bool operator==(Object obj) {
    if (obj is Predicate)
      return ruleIndex == obj.ruleIndex &&
          predIndex == obj.predIndex &&
          isCtxDependent == obj.isCtxDependent;
    return false;
  }

  String toString() => "{$ruleIndex:$predIndex}?";
}

class And extends SemanticContext {

  final List<SemanticContext> opnds;

  And(SemanticContext a, SemanticContext b)
    : opnds = new List<SemanticContext> () {
    Set<SemanticContext> operands = new HashSet<SemanticContext>();
    if (a is And) operands.addAll(a.opnds);
    else opnds.add(a);
    if (b is And) operands.addAll(b.opnds);
    else operands.add(b);
    opnds.addAll(operands);
  }

  bool operator==(Object obj) {
    if (obj is! And) return false;
    return opnds == (obj as And).opnds;
  }

  int get hashCode {
    return MurmurHash.calcHashCode(opnds, runtimeType.hashCode);
  }

  bool eval(Recognizer parser, RuleContext outerContext) {
    for (SemanticContext opnd in opnds) {
      if (!opnd.eval(parser, outerContext)) return false;
    }
    return true;
  }

  String toString() => opnds.join('&&');
}

class Or extends SemanticContext {

  final List<SemanticContext> opnds;

  Or(SemanticContext a, SemanticContext b) :
    opnds = new List<SemanticContext> () {
    Set<SemanticContext> operands = new HashSet<SemanticContext>();
    if (a is Or) operands.addAll(a.opnds);
    else operands.add(a);
    if (b is Or) operands.addAll(b.opnds);
    else operands.add(b);
    opnds.addAll(operands);
  }

  bool operator==(Object obj) {
    if (obj is! Or) return false;
    return opnds == (obj as Or).opnds;
  }

  int  get hashCode {
    return MurmurHash.calcHashCode(opnds, runtimeType.hashCode);
  }

  bool eval(Recognizer parser, RuleContext outerContext) {
    for (SemanticContext opnd in opnds) {
      if (opnd.eval(parser, outerContext)) return true;
    }
    return false;
  }

  String toString() => opnds.join("||");
}
