part of antlr4dart;

/// Used to cache [PredictionContext] objects. Its used for the shared
/// context cash associated with contexts in DFA states. This cache can be
/// used for both lexers and parsers.
class PredictionContextCache {

  var _cache = new HashMap<PredictionContext, PredictionContext>();

  int get length => _cache.length;

  /// Add a [context] to the cache and return it.
  ///
  /// If the [context] already exists, return that one instead and do not
  /// add a new context to the cache.
  PredictionContext add(PredictionContext context) {
    if (context == PredictionContext.EMPTY) return PredictionContext.EMPTY;
    PredictionContext existing = _cache[context];
    if (existing != null) return existing;
    _cache[context] = context;
    return context;
  }

  PredictionContext get(PredictionContext context) => _cache[context];
}

abstract class PredictionContext {

  /// Represents `$` in local context prediction, which means wildcard.
  /// `*+x = *`.
  static final EmptyPredictionContext EMPTY = new EmptyPredictionContext();

  static final int _INITIAL_HASH = 1;

  /// Represents `$` in a list in full context mode, when `$` doesn't mean
  /// wildcard:
  ///     $ + x = [$,x]
  /// Here,
  ///     $ = [EMPTY_RETURN_STATE]
  static final int EMPTY_RETURN_STATE = pow(2, 53) - 1;

  static int globalNodeCount = 0;

  final int id = globalNodeCount++;

  /// Stores the computed hash code of this [PredictionContext]. The hash
  /// code is computed in parts to match the following reference algorithm.
  ///
  ///
  ///      int _referenceHashCode() {
  ///        int hash = MurmurHash.initialize(INITIAL_HASH);
  ///        for (int i = 0; i < length; i++) {
  ///          hash = MurmurHash.update(hash, getParent(i));
  ///        }
  ///        for (int i = 0; i < length; i++) {
  ///          hash = MurmurHash.update(hash, returnState(i));
  ///        }
  ///        hash = MurmurHash.finish(hash, 2 * length);
  ///        return hash;
  ///      }
  final int cachedHashCode;

  PredictionContext._internal(this.cachedHashCode);

  /// Convert a [RuleContext] tree to a [PredictionContext] graph.
  ///
  /// Return [EMPTY] if `outerContext` is empty or `null`.
  factory PredictionContext.fromRuleContext(Atn atn, RuleContext outerContext) {
    if (outerContext == null) outerContext = RuleContext.EMPTY;
    // if we are in RuleContext of start rule, s, then PredictionContext
    // is EMPTY. Nobody called us. (if we are empty, return empty)
    if (outerContext.parent == null || outerContext == RuleContext.EMPTY) {
      return PredictionContext.EMPTY;
    }
    // If we have a parent, convert it to a PredictionContext graph
    PredictionContext parent = EMPTY;
    if (outerContext.parent != null) {
      parent = new PredictionContext.fromRuleContext(atn, outerContext.parent);
    }
    AtnState state = atn.states[outerContext.invokingState];
    RuleTransition transition = state.getTransition(0);
    return new SingletonPredictionContext.empty(
        parent, transition.followState.stateNumber);
  }

  int get length;

  /// This means only the [EMPTY] context is in set.
  bool get isEmpty => this == EMPTY;

  bool get hasEmptyPath => returnStateFor(length - 1) == EMPTY_RETURN_STATE;

  int get hashCode => cachedHashCode;

  bool operator==(Object obj);

  PredictionContext parentFor(int index);

  int returnStateFor(int index);

  static PredictionContext merge(PredictionContext contextA,
                                 PredictionContext contextB,
                                 bool rootIsWildcard,
                                 DoubleKeyMap<PredictionContext,
                                              PredictionContext,
                                              PredictionContext> mergeCache) {
    // share same graph if both same
    if ((contextA == null && contextB == null)
        || contextA == contextB
        || (contextA != null && contextA == contextB)) {
      return contextA;
    }
    if (contextA is SingletonPredictionContext
        && contextB is SingletonPredictionContext) {
      return mergeSingletons(contextA, contextB, rootIsWildcard, mergeCache);
    }
    // At least one of a or b is list
    // If one is $ and rootIsWildcard, return $ as * wildcard
    if (rootIsWildcard) {
      if (contextA is EmptyPredictionContext) return contextA;
      if (contextB is EmptyPredictionContext) return contextB;
    }
    // convert singleton so both are arrays to normalize
    if (contextA is SingletonPredictionContext )
      contextA = new ListPredictionContext.from(contextA);
    if ( contextB is SingletonPredictionContext)
      contextB = new ListPredictionContext.from(contextB);
    return mergeLists(contextA, contextB, rootIsWildcard, mergeCache);
  }

  /// Merge two [SingletonPredictionContext] instances.
  ///
  /// [contextA] is the first [SingletonPredictionContext].
  /// [contextB] is the second [SingletonPredictionContext].
  /// [rootIsWildcard] is `true` if this is a local-context merge,
  /// otherwise `false` to indicate a full-context merge.
  static PredictionContext mergeSingletons(SingletonPredictionContext contextA,
                                           SingletonPredictionContext contextB,
                                           bool rootIsWildcard,
                                           DoubleKeyMap<PredictionContext,
                                                        PredictionContext,
                                                        PredictionContext> mergeCache) {
    if (mergeCache != null) {
      PredictionContext previous = mergeCache.get(contextA,contextB);
      if (previous != null) return previous;
      previous = mergeCache.get(contextB,contextA);
      if (previous != null) return previous;
    }
    PredictionContext rootMerge = mergeRoot(contextA, contextB, rootIsWildcard);
    if (rootMerge != null) {
      if (mergeCache != null) mergeCache.put(contextA, contextB, rootMerge);
      return rootMerge;
    }
    if (contextA.returnState == contextB.returnState) {
      var parent = merge(
          contextA.parent, contextB.parent, rootIsWildcard, mergeCache);
      if (parent == contextA.parent) return contextA;
      if (parent == contextB.parent) return contextB;
      var a = new SingletonPredictionContext.empty(parent, contextA.returnState);
      if (mergeCache != null) mergeCache.put(contextA, contextB, a);
      return a;
    } else {
      PredictionContext singleParent = null;
      if (contextA == contextB
          || (contextA.parent != null && contextA.parent == contextB.parent)) {
        singleParent = contextA.parent;
      }
      if (singleParent != null) {
        List<int> payloads = [contextA.returnState, contextB.returnState];
        if (contextA.returnState > contextB.returnState) {
          payloads[0] = contextB.returnState;
          payloads[1] = contextA.returnState;
        }
        List<PredictionContext> parents = [singleParent, singleParent];
        PredictionContext a = new ListPredictionContext(parents, payloads);
        if (mergeCache != null) mergeCache.put(contextA, contextB, a);
        return a;
      }
      List<int> payloads = [contextA.returnState, contextB.returnState];
      List<PredictionContext> parents = [contextA.parent, contextB.parent];
      if (contextA.returnState > contextB.returnState) {
        payloads[0] = contextB.returnState;
        payloads[1] = contextA.returnState;
        parents = <PredictionContext>[contextB.parent, contextA.parent];
      }
      PredictionContext a = new ListPredictionContext(parents, payloads);
      if (mergeCache != null) mergeCache.put(contextA, contextB, a);
      return a;
    }
  }

  /// Handle case where at least one of `a` or `b` is [EMPTY]. In
  /// the following diagrams, the symbol `$` is used to represent [EMPTY].
  ///
  /// [contextA] is the first [SingletonPredictionContext].
  /// [contextB] is the second [SingletonPredictionContext].
  /// [rootIsWildcard] `true` if this is a local-context merge,
  /// otherwise `false` to indicate a full-context merge.
  static PredictionContext mergeRoot(SingletonPredictionContext contextA,
                                     SingletonPredictionContext contextB,
                                     bool rootIsWildcard) {
    if (rootIsWildcard) {
      if (contextA == EMPTY) return EMPTY;
      if (contextB == EMPTY) return EMPTY;
    } else {
      if (contextA == EMPTY && contextB == EMPTY) return EMPTY;
      if (contextA == EMPTY) {
        var payloads = [contextB.returnState, EMPTY_RETURN_STATE];
        var parents = [contextB.parent, null];
        var joined = new ListPredictionContext(parents, payloads);
        return joined;
      }
      if (contextB == EMPTY) {
        var payloads = [contextA.returnState, EMPTY_RETURN_STATE];
        var parents = [contextA.parent, null];
        var joined = new ListPredictionContext(parents, payloads);
        return joined;
      }
    }
    return null;
  }

  /// Merge two [ListPredictionContext] instances.
  static PredictionContext mergeLists(ListPredictionContext contextA,
                                      ListPredictionContext contextB,
                                      bool rootIsWildcard,
                                      DoubleKeyMap<PredictionContext,
                                                   PredictionContext,
                                                   PredictionContext> mergeCache) {
    if (mergeCache != null) {
      PredictionContext previous = mergeCache.get(contextA,contextB);
      if (previous != null) return previous;
      previous = mergeCache.get(contextB,contextA);
      if (previous != null) return previous;
    }
    int i = 0;
    int j = 0;
    int k = 0;
    List<int> mergedReturnStates = new List<int>(
        contextA.returnStates.length + contextB.returnStates.length);
    var mergedParents = new List<PredictionContext>(
        contextA.returnStates.length + contextB.returnStates.length);
    // walk and merge to yield mergedParents, mergedReturnStates
    while (i < contextA.returnStates.length
        && j < contextB.returnStates.length) {
      PredictionContext aParent = contextA.parents[i];
      PredictionContext bParent = contextB.parents[j];
      if (contextA.returnStates[i] == contextB.returnStates[j]) {
        // same payload (stack tops are equal), must yield merged singleton
        int payload = contextA.returnStates[i];
        bool both$ = payload == EMPTY_RETURN_STATE
            && aParent == null && bParent == null;
        bool axAx = (aParent != null && bParent != null)
            && aParent == bParent;
        if (both$ || axAx) {
          mergedParents[k] = aParent; // choose left
          mergedReturnStates[k] = payload;
        } else {
          var mergedParent = merge(
              aParent, bParent, rootIsWildcard, mergeCache);
          mergedParents[k] = mergedParent;
          mergedReturnStates[k] = payload;
        }
        i++; // hop over left one as usual
        j++; // but also skip one in right side since we merge
      } else if (contextA.returnStates[i] < contextB.returnStates[j]) {
        mergedParents[k] = aParent;
        mergedReturnStates[k] = contextA.returnStates[i];
        i++;
      } else {
        mergedParents[k] = bParent;
        mergedReturnStates[k] = contextB.returnStates[j];
        j++;
      }
      k++;
    }
    // copy over any payloads remaining in either array
    if (i < contextA.returnStates.length) {
      for (int p = i; p < contextA.returnStates.length; p++) {
        mergedParents[k] = contextA.parents[p];
        mergedReturnStates[k] = contextA.returnStates[p];
        k++;
      }
    } else {
      for (int p = j; p < contextB.returnStates.length; p++) {
        mergedParents[k] = contextB.parents[p];
        mergedReturnStates[k] = contextB.returnStates[p];
        k++;
      }
    }
    if (k < mergedParents.length) {
      if (k == 1) {
        var a_ = new SingletonPredictionContext.empty(
                            mergedParents[0],
                            mergedReturnStates[0]);
        if (mergeCache != null) mergeCache.put(contextA, contextB, a_);
        return a_;
      }
      mergedParents = mergedParents.getRange(0, k).toList();
      mergedReturnStates = mergedReturnStates.getRange(0, k).toList();
    }
    var m = new ListPredictionContext(mergedParents, mergedReturnStates);
    if (m == contextA) {
      if (mergeCache != null) mergeCache.put(contextA, contextB, contextA);
      return contextA;
    }
    if (m == contextB) {
      if (mergeCache != null) mergeCache.put(contextA, contextB, contextB);
      return contextB;
    }
    _combineCommonParents(mergedParents);
    if (mergeCache != null) mergeCache.put(contextA, contextB, m);
    return m;
  }

  /// Make pass over all **M** `parents`; merge any `==` ones.
  static void _combineCommonParents(List<PredictionContext> parents) {
    var uniqueParents = new HashMap<PredictionContext, PredictionContext>();
    for (int p = 0; p < parents.length; p++) {
      PredictionContext parent = parents[p];
      if (!uniqueParents.containsKey(parent)) { // don't replace
        uniqueParents[parent] = parent;
      }
    }
    for (int p = 0; p < parents.length; p++) {
      parents[p] = uniqueParents[parents[p]];
    }
  }

  static PredictionContext getCachedContext(PredictionContext context,
                                            PredictionContextCache contextCache,
                                            HashMap<PredictionContext,
                                                    PredictionContext> visited) {
    if (context.isEmpty) return context;
    PredictionContext existing = visited[context];
    if (existing != null) return existing;
    existing = contextCache.get(context);
    if (existing != null) {
      visited[context] = existing;
      return existing;
    }
    bool changed = false;
    var parents = new List<PredictionContext>(context.length);
    for (int i = 0; i < parents.length; i++) {
      var parent = getCachedContext(context.parentFor(i), contextCache, visited);
      if (changed || parent != context.parentFor(i)) {
        if (!changed) {
          parents = new List<PredictionContext>(context.length);
          for (int j = 0; j < context.length; j++) {
            parents[j] = context.parentFor(j);
          }
          changed = true;
        }
        parents[i] = parent;
      }
    }
    if (!changed) {
      contextCache.add(context);
      visited[context] = context;
      return context;
    }
    PredictionContext updated;
    if (parents.length == 0) {
      updated = EMPTY;
    } else if (parents.length == 1) {
      updated = new SingletonPredictionContext
          .empty(parents[0], context.returnStateFor(0));
    } else {
      ListPredictionContext listPredictionContext = context;
      updated = new ListPredictionContext(
          parents, listPredictionContext.returnStates);
    }
    contextCache.add(updated);
    visited[updated] = updated;
    visited[context] = updated;
    return updated;
  }

  static List<PredictionContext> getAllContextNodes(PredictionContext context,
                                                    [List<PredictionContext> nodes,
                                                    Map<PredictionContext,
                                                        PredictionContext> visited]) {
    nodes = (nodes != null) ? nodes : new List<PredictionContext>();
    visited = (visited != null) ? visited
        : new HashMap<PredictionContext, PredictionContext>();
    if (!(context == null || visited.containsKey(context))) {;
      visited[context] = context;
      nodes.add(context);
      for (int i = 0; i < context.length; i++) {
        getAllContextNodes(context.parentFor(i), nodes, visited);
      }
    }
    return nodes;
  }

  String toString() => "[]";

  List<String> toStrings(Recognizer recognizer,
                         PredictionContext stop,
                         int currentState) {
    stop = (stop != null) ? stop : EMPTY;
    List<String> result = new List<String>();
    outer: for (int perm = 0; ; perm++) {
      int offset = 0;
      bool last = true;
      PredictionContext prediction = this;
      int stateNumber = currentState;
      StringBuffer localBuffer = new StringBuffer("[");
      while (!prediction.isEmpty && prediction != stop) {
        int index = 0;
        if (prediction.length > 0) {
          int bits = 1;
          while ((1 << bits) < prediction.length) bits++;
          int mask = (1 << bits) - 1;
          index = (perm >> offset) & mask;
          last = last && (index >= prediction.length - 1);
          if (index >= prediction.length) continue outer;
          offset += bits;
        }
        if (recognizer != null) {
          if (localBuffer.length > 1) localBuffer.write(' ');
          Atn atn = recognizer.atn;
          AtnState s = atn.states[stateNumber];
          String ruleName = recognizer.ruleNames[s.ruleIndex];
          localBuffer.write(ruleName);
        } else if (prediction.returnStateFor(index) != EMPTY_RETURN_STATE) {
          if (!prediction.isEmpty) {
            // first char is '[', if more than that this isn't the first rule
            if (localBuffer.length > 1) localBuffer.write(' ');
            localBuffer.write(prediction.returnStateFor(index));
          }
        }
        stateNumber = prediction.returnStateFor(index);
        prediction = prediction.parentFor(index);
      }
      localBuffer.write("]");
      result.add(localBuffer.toString());
      if (last) break;
    }
    return result;
  }

  static int _calculateEmptyHashCode() {
    int hash = MurmurHash.initialize(_INITIAL_HASH);
    hash = MurmurHash.finish(hash, 0);
    return hash;
  }

  static int _calculateHashCode(PredictionContext parent, int returnState) {
    int hash = MurmurHash.initialize(_INITIAL_HASH);
    hash = MurmurHash.update(hash, parent.hashCode);
    hash = MurmurHash.update(hash, returnState);
    hash = MurmurHash.finish(hash, 2);
    return hash;
  }

  static int _calculateHashCodes(List<PredictionContext> parents,
                                 List<int> returnStates) {
    int hash = MurmurHash.initialize(_INITIAL_HASH);
    for (PredictionContext parent in parents) {
      hash = MurmurHash.update(hash, parent.hashCode);
    }
    for (int returnState in returnStates) {
      hash = MurmurHash.update(hash, returnState);
    }
    hash = MurmurHash.finish(hash, 2 * parents.length);
    return hash;
  }
}


class EmptyPredictionContext extends SingletonPredictionContext {
  EmptyPredictionContext() : super(null, PredictionContext.EMPTY_RETURN_STATE);

  bool get isEmpty => true;

  int get length => 1;

  PredictionContext parentFor(int index) => null;

  int returnStateFor(int index) => returnState;

  String toString() => r"$";
}

class ListPredictionContext extends PredictionContext {

  /// Parent can be `null` only if full context mode and we make a list from
  /// [PredictionContext.EMPTY] and non-empty.
  ///
  /// We merge [PredictionContext.EMPTY] by using null parent and
  /// `returnState == PredictionContext.EMPTY_RETURN_STATE`.
  final List<PredictionContext> parents;

  ///  [PredictionContext.EMPTY_RETURN_STATE] is always last.
  final List<int> returnStates;

  ListPredictionContext(List<PredictionContext> parents, List<int> returnStates)
      : this.parents = parents,
        this.returnStates = returnStates,
        super._internal(PredictionContext
            ._calculateHashCodes(parents, returnStates)) {
    assert(parents != null && parents.length > 0);
    assert(returnStates != null && returnStates.length > 0);
  }

  ListPredictionContext.from(SingletonPredictionContext a)
    : this([a.parent], [a.returnState]);

  bool get isEmpty => returnStates[0] == PredictionContext.EMPTY_RETURN_STATE;

  int get length => returnStates.length;

  PredictionContext parentFor(int index) => parents[index];

  int returnStateFor(int index) => returnStates[index];

  bool operator==(Object other) {
    return other is ListPredictionContext
        && hashCode == other.hashCode
        && returnStates == other.returnStates
        && parents == other.parents;
  }

  String toString() {
    if (isEmpty) return "[]";
    StringBuffer sb = new StringBuffer("[");
    for (int i = 0; i < returnStates.length; i++) {
      if (i > 0) sb.write(", ");
      if (returnStates[i] == PredictionContext.EMPTY_RETURN_STATE) {
        sb.write(r"$");
        continue;
      }
      sb.write(returnStates[i]);
      if (parents[i] != null) {
        sb
            ..write(' ')
            ..write(parents[i]);
      } else {
        sb.write("null");
      }
    }
    sb.write("]");
    return sb.toString();
  }
}

class SingletonPredictionContext extends PredictionContext {

  final PredictionContext parent;
  final int returnState;

  SingletonPredictionContext(PredictionContext parent, int returnState)
    : this.parent = parent,
      this.returnState = returnState,
      super._internal((parent != null)
          ? PredictionContext._calculateHashCode(parent, returnState)
          : PredictionContext._calculateEmptyHashCode()) {
    assert(returnState != AtnState.INVALID_STATE_NUMBER);
  }

  factory SingletonPredictionContext.empty(PredictionContext parent,
                                           int returnState) {
    if (returnState == PredictionContext.EMPTY_RETURN_STATE && parent == null) {
      // someone can pass in the bits of an array ctx that mean $
      return PredictionContext.EMPTY;
    }
    return new SingletonPredictionContext(parent, returnState);
  }

  int get length => 1;

  PredictionContext parentFor(int index) {
    assert(index == 0);
    return parent;
  }

  int returnStateFor(int index) {
    assert(index == 0);
    return returnState;
  }

  bool operator ==(Object other) {
    return other is SingletonPredictionContext
        && hashCode == other.hashCode
        && returnState == other.returnState
        && parent == other.parent;
  }

  String toString() {
    String up = parent != null ? parent.toString() : "";
    if (up.length == 0) {
      if (returnState == PredictionContext.EMPTY_RETURN_STATE) {
        return r"$";
      }
      return "$returnState";
    }
    return "$returnState $up";
  }
}