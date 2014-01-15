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

  /**
   * Evaluate the precedence predicates for the context and reduce the result.
   *
   * [parser] is the parser instance.
   * [outerContext] is the current parser context object.
   * Return the simplified semantic context after precedence predicates are
   * evaluated, which will be one of the following values.
   *
   * * [SemanticContext.NONE]: if the predicate simplifies to `true` after precedence predicates
   *   are evaluated.
   * * `null`: if the predicate simplifies to `false` after precedence predicates
   *   are evaluated.
   * * `this`: if the semantic context is not changed as a result of precedence
   *   predicate evaluation.
   * * A non-`null` [SemanticContext]: the new simplified semantic context after
   *   precedence predicates are evaluated.
   */
  SemanticContext evalPrecedence(Recognizer parser, RuleContext outerContext) {
    return this;
  }

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

  static List<PrecedencePredicate> _filterPrecedencePredicates(Set<SemanticContext> iterable) {
    List<PrecedencePredicate> result = null;
    List<SemanticContext> copy = new List<SemanticContext>.from(iterable);
    for (Iterator<SemanticContext> iterator = copy.iterator; iterator.moveNext();) {
      SemanticContext context = iterator.current;
      if (context is PrecedencePredicate) {
        if (result == null) {
          result = new List<PrecedencePredicate>();
        }
        result.add(context);
        iterable.remove(context);
      }
    }
    if (result == null) {
      return <PrecedencePredicate>[];
    }
    return result;
  }

  static PrecedencePredicate _min(List<PrecedencePredicate> predicates) {
    PrecedencePredicate min = predicates[0];
    for(int i = 1; i < predicates.length; i++) {
      if (min.compareTo(predicates[i]) > 0) {
        min = predicates[i];
      }
    }
    return min;
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
    var precedencePredicates = SemanticContext._filterPrecedencePredicates(operands);
    if (!precedencePredicates.isEmpty) {
      // interested in the transition with the lowest precedence
      var reduced = SemanticContext._min(precedencePredicates);
      operands.add(reduced);
    }
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

  SemanticContext evalPrecedence(Recognizer parser, RuleContext outerContext) {
    bool differs = false;
    List<SemanticContext> operands = new List<SemanticContext>();
    for (SemanticContext context in opnds) {
      SemanticContext evaluated = context.evalPrecedence(parser, outerContext);
      differs = differs || (evaluated != context);
      if (evaluated == null) {
        // The AND context is false if any element is false
        return null;
      } else if (evaluated != SemanticContext.NONE) {
        // Reduce the result by skipping true elements
        operands.add(evaluated);
      }
    }
    if (!differs) return this;
    if (operands.isEmpty) {
      // all elements were true, so the AND context is true
      return SemanticContext.NONE;
    }
    SemanticContext result = operands[0];
    for (int i = 1; i < operands.length; i++) {
      result = SemanticContext.and(result, operands[i]);
    }
    return result;
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

  SemanticContext evalPrecedence(Recognizer parser, RuleContext outerContext) {
    bool differs = false;
    List<SemanticContext> operands = new List<SemanticContext>();
    for (SemanticContext context in opnds) {
      SemanticContext evaluated = context.evalPrecedence(parser, outerContext);
      differs = differs || (evaluated != context);
      if (evaluated == SemanticContext.NONE) {
        // The OR context is true if any element is true
        return SemanticContext.NONE;
      } else if (evaluated != null) {
        // Reduce the result by skipping false elements
        operands.add(evaluated);
      }
    }
    if (!differs) return this;
    if (operands.isEmpty) {
      // all elements were false, so the OR context is false
      return null;
    }
    SemanticContext result = operands[0];
    for (int i = 1; i < operands.length; i++) {
      result = SemanticContext.or(result, operands[i]);
    }
    return result;
  }

  String toString() => opnds.join("||");
}

class PrecedencePredicate extends SemanticContext implements Comparable<PrecedencePredicate> {
  final int precedence;

  PrecedencePredicate([this.precedence = 0]);

  bool eval(Recognizer parser, RuleContext outerContext) {
    return parser.precpred(outerContext, precedence);
  }

  SemanticContext evalPrecedence(Recognizer parser, RuleContext outerContext) {
    if (parser.precpred(outerContext, precedence)) {
      return SemanticContext.NONE;
    }
    return null;
  }

  int compareTo(PrecedencePredicate o) {
    return precedence - o.precedence;
  }

  int get hashCode {
    int hash = 1;
    hash = 31 * hash + precedence;
    return hash;
  }

  bool operator==(Object obj) {
    if (obj is PrecedencePredicate)
      return precedence == obj.precedence;
    return false;
  }

  String toString() => super.toString();
}
