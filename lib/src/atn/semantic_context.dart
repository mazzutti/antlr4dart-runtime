part of antlr4dart;

/// A tree structure used to record the semantic context in which
/// an ATN configuration is valid.  It's either a single predicate,
/// a conjunction `p1 && p2`, or a sum of products `p1 || p2`.
abstract class SemanticContext {

  static final SemanticContext NONE = new Predicate();

  /// For context independent predicates, we evaluate them without a local
  /// context (i.e., null context). That way, we can evaluate them without
  /// having to create proper rule-specific context during prediction (as
  /// opposed to the parser, which creates them naturally). In a practical
  /// sense, this avoids a cast error from [RuleContext] to myruleContext.
  ///
  /// For context dependent predicates, we must pass in a local context so that
  /// references such as `$arg` evaluate properly as `localCtx.arg`. We only
  /// capture context dependent predicates in the context in which we begin
  /// prediction, so we passed in the outer context here in case of context
  /// dependent predicate evaluation.
  ///
  /// [parser] is the parser instance.
  /// [outerContext] is the current parser context object.
  bool eval(Recognizer parser, RuleContext outerContext);

  /// Evaluate the precedence predicates for the context and reduce the result.
  ///
  /// [parser] is the parser instance.
  /// [outerContext] is the current parser context object.
  ///
  /// Return the simplified semantic context after precedence predicates are
  /// evaluated, which will be one of the following values:
  /// * [NONE]: if the predicate simplifies to `true` after
  ///   precedence predicates are evaluated.
  /// * `null`: if the predicate simplifies to `false` after precedence
  ///   predicates are evaluated.
  /// * `this`: if the semantic context is not changed as a result of precedence
  ///   predicate evaluation.
  /// * A non-`null` [SemanticContext]: the new simplified semantic context
  ///   after precedence predicates are evaluated.
  SemanticContext evalPrecedence(Recognizer parser, RuleContext outerContext) {
    return this;
  }

  static SemanticContext and(SemanticContext a, SemanticContext b) {
    if (a == null || a == NONE) return b;
    if (b == null || b == NONE) return a;
    And result = new And(a, b);
    if (result.operands.length == 1) return result.operands[0];
    return result;
  }

  ///  See [ParserATNSimulator.predsForAmbigAlts].
  static SemanticContext or(SemanticContext a, SemanticContext b) {
    if (a == null) return b;
    if (b == null) return a;
    if (a == NONE || b == NONE) return NONE;
    Or result = new Or(a, b);
    if (result.operands.length == 1) return result.operands[0];
    return result;
  }

  static _filterPrecPredicates(Set<SemanticContext> iterable) {
    List<PrecedencePredicate> result = null;
    List<SemanticContext> copy = new List<SemanticContext>.from(iterable);
    for (Iterator iterator = copy.iterator; iterator.moveNext();) {
      SemanticContext context = iterator.current;
      if (context is PrecedencePredicate) {
        if (result == null) result = new List<PrecedencePredicate>();
        result.add(context);
        iterable.remove(context);
      }
    }
    if (result == null) return <PrecedencePredicate>[];
    return result;
  }

  static PrecedencePredicate _min(List<PrecedencePredicate> predicates) {
    PrecedencePredicate min = predicates[0];
    for(int i = 1; i < predicates.length; i++) {
      if (min.compareTo(predicates[i]) > 0) min = predicates[i];
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
    return parser.semanticPredicate(localctx, ruleIndex, predIndex);
  }

  int get hashCode {
    int hashCode = MurmurHash.initialize();
    hashCode = MurmurHash.update(hashCode, ruleIndex);
    hashCode = MurmurHash.update(hashCode, predIndex);
    hashCode = MurmurHash.update(hashCode, isCtxDependent ? 1 : 0);
    hashCode = MurmurHash.finish(hashCode, 3);
    return hashCode;
  }

  bool operator==(Object other) {
    return other is Predicate
        && ruleIndex == other.ruleIndex
        && predIndex == other.predIndex
        && isCtxDependent == other.isCtxDependent;
  }

  String toString() => "{$ruleIndex:$predIndex}?";
}

class And extends SemanticContext {

  final List<SemanticContext> operands;

  And(SemanticContext a, SemanticContext b)
      : operands = new List<SemanticContext> () {
    Set<SemanticContext> opnds = new HashSet<SemanticContext>();
    if (a is And) {
      opnds.addAll(a.operands);
    } else {
      operands.add(a);
    }
    if (b is And) {
      opnds.addAll(b.operands);
    } else {
      opnds.add(b);
    }
    var precPredicates = SemanticContext._filterPrecPredicates(opnds);
    if (!precPredicates.isEmpty) {
      // interested in the transition with the lowest precedence
      var reduced = SemanticContext._min(precPredicates);
      opnds.add(reduced);
    }
    operands.addAll(opnds);
  }

  int get hashCode => MurmurHash.calcHashCode(operands, runtimeType.hashCode);

  bool operator==(Object other) =>other is And && operands == other.operands;

  bool eval(Recognizer parser, RuleContext outerContext) {
    for (SemanticContext opnd in operands) {
      if (!opnd.eval(parser, outerContext)) return false;
    }
    return true;
  }

  SemanticContext evalPrecedence(Recognizer parser, RuleContext outerContext) {
    bool differs = false;
    List<SemanticContext> opnds = new List<SemanticContext>();
    for (SemanticContext context in operands) {
      SemanticContext evaluated = context.evalPrecedence(parser, outerContext);
      differs = differs || (evaluated != context);
      if (evaluated == null) {
        // The AND context is false if any element is false
        return null;
      } else if (evaluated != SemanticContext.NONE) {
        // Reduce the result by skipping true elements
        opnds.add(evaluated);
      }
    }
    if (!differs) return this;
    if (opnds.isEmpty) {
      // all elements were true, so the AND context is true
      return SemanticContext.NONE;
    }
    SemanticContext result = opnds[0];
    for (int i = 1; i < opnds.length; i++) {
      result = SemanticContext.and(result, opnds[i]);
    }
    return result;
  }

  String toString() => operands.join('&&');
}

class Or extends SemanticContext {

  final List<SemanticContext> operands;

  Or(SemanticContext a, SemanticContext b) :
    operands = new List<SemanticContext> () {
    var opnds = new HashSet<SemanticContext>();
    if (a is Or) {
      opnds.addAll(a.operands);
    } else {
      opnds.add(a);
    }
    if (b is Or) {
      opnds.addAll(b.operands);
    } else {
      opnds.add(b);
    }
    operands.addAll(opnds);
  }

  int  get hashCode => MurmurHash.calcHashCode(operands, runtimeType.hashCode);

  bool operator==(Object other) => other is Or && operands == other.operands;

  bool eval(Recognizer parser, RuleContext outerContext) {
    for (SemanticContext opnd in operands) {
      if (opnd.eval(parser, outerContext)) return true;
    }
    return false;
  }

  SemanticContext evalPrecedence(Recognizer parser, RuleContext outerContext) {
    bool differs = false;
    var opnds = new List<SemanticContext>();
    for (SemanticContext context in operands) {
      SemanticContext evaluated = context.evalPrecedence(parser, outerContext);
      differs = differs || (evaluated != context);
      if (evaluated == SemanticContext.NONE) {
        // The OR context is true if any element is true
        return SemanticContext.NONE;
      } else if (evaluated != null) {
        // Reduce the result by skipping false elements
        opnds.add(evaluated);
      }
    }
    if (!differs) return this;
    if (opnds.isEmpty) {
      // all elements were false, so the OR context is false
      return null;
    }
    SemanticContext result = opnds[0];
    for (int i = 1; i < opnds.length; i++) {
      result = SemanticContext.or(result, opnds[i]);
    }
    return result;
  }

  String toString() => operands.join("||");
}

class PrecedencePredicate extends SemanticContext
                          implements Comparable<PrecedencePredicate> {

  final int precedence;

  PrecedencePredicate([this.precedence = 0]);

  int get hashCode => 31 + precedence;

  bool eval(Recognizer parser, RuleContext outerContext) {
    return parser.precedencePredicate(outerContext, precedence);
  }

  SemanticContext evalPrecedence(Recognizer parser, RuleContext outerContext) {
    return parser
        .precedencePredicate(outerContext, precedence) ? SemanticContext.NONE : null;
  }

  int compareTo(PrecedencePredicate other) => precedence - other.precedence;

  bool operator==(Object other) {
    return other is PrecedencePredicate && precedence == other.precedence;
  }

  String toString() => super.toString();
}
