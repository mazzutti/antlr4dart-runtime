part of antlr4dart;

abstract class PredictionContext {

  /// Represents `$` in local context prediction, which means wildcard.
  /// `*+x = *`.
  static final EmptyPredictionContext EMPTY = new EmptyPredictionContext();

  static final int _INITIAL_HASH = 1;

  /// Represents `$` in an array in full context mode, when `$`
  /// doesn't mean wildcard: `$ + x = [$,x]`. Here,
  /// `$ = [EMPTY_RETURN_STATE]`.
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
  /// Return [EMPTY] if `outerContext` is empty or null.
  static PredictionContext fromRuleContext(Atn atn, RuleContext outerContext) {
    if (outerContext == null) outerContext = RuleContext.EMPTY;
    // if we are in RuleContext of start rule, s, then PredictionContext
    // is EMPTY. Nobody called us. (if we are empty, return empty)
    if (outerContext.parent == null || outerContext == RuleContext.EMPTY) {
      return PredictionContext.EMPTY;
    }
    // If we have a parent, convert it to a PredictionContext graph
    PredictionContext parent = EMPTY;
    if (outerContext.parent != null) {
      parent = PredictionContext.fromRuleContext(atn, outerContext.parent);
    }
    AtnState state = atn.states[outerContext.invokingState];
    RuleTransition transition = state.transition(0);
    return SingletonPredictionContext.create(parent, transition.followState.stateNumber);
  }

  int get length;

  PredictionContext getParent(int index);

  int getReturnState(int index);

  /// This means only the [EMPTY] context is in set.
  bool get isEmpty => this == EMPTY;

  bool get hasEmptyPath => getReturnState(length - 1) == EMPTY_RETURN_STATE;

  int get hashCode => cachedHashCode;

  bool operator==(Object obj);

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

  static int _calculateHashCodes(List<PredictionContext> parents, List<int> returnStates) {
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

  // dispatch
  static PredictionContext merge(
       PredictionContext a,
       PredictionContext b,
       bool rootIsWildcard,
       DoubleKeyMap<PredictionContext,PredictionContext,PredictionContext> mergeCache) {
    // share same graph if both same
    if ((a == null && b == null) || a == b || (a != null && a == b) ) return a;
    if ( a is SingletonPredictionContext && b is SingletonPredictionContext) {
      return mergeSingletons(a, b, rootIsWildcard, mergeCache);
    }
    // At least one of a or b is list
    // If one is $ and rootIsWildcard, return $ as * wildcard
    if (rootIsWildcard) {
      if (a is EmptyPredictionContext) return a;
      if (b is EmptyPredictionContext) return b;
    }
    // convert singleton so both are arrays to normalize
    if (a is SingletonPredictionContext ) {
      a = new ListPredictionContext.from(a);
    }
    if ( b is SingletonPredictionContext) {
      b = new ListPredictionContext.from(b);
    }
    return mergeLists(a, b, rootIsWildcard, mergeCache);
  }

  /// Merge two [SingletonPredictionContext] instances.
  ///
  /// [a] is the first [SingletonPredictionContext]
  /// [b] is the second [SingletonPredictionContext]
  /// [rootIsWildcard] is `true` if this is a local-context merge,
  /// otherwise `false` to indicate a full-context merge
  static PredictionContext mergeSingletons(
        SingletonPredictionContext a,
        SingletonPredictionContext b,
        bool rootIsWildcard,
        DoubleKeyMap<PredictionContext,PredictionContext,PredictionContext> mergeCache) {
    if (mergeCache != null) {
      PredictionContext previous = mergeCache.get(a,b);
      if (previous != null) return previous;
      previous = mergeCache.get(b,a);
      if (previous != null) return previous;
    }
    PredictionContext rootMerge = mergeRoot(a, b, rootIsWildcard);
    if (rootMerge != null) {
      if (mergeCache != null) mergeCache.put(a, b, rootMerge);
      return rootMerge;
    }
    if ( a.returnState==b.returnState ) { // a == b
      PredictionContext parent = merge(a.parent, b.parent, rootIsWildcard, mergeCache);
      // if parent is same as existing a or b parent or reduced to a parent, return it
      if (parent == a.parent) return a; // ax + bx = ax, if a=b
      if (parent == b.parent) return b; // ax + bx = bx, if a=b
      // else: ax + ay = a'[x,y]
      // merge parents x and y, giving array node with x,y then remainders
      // of those graphs.  dup a, a' points at merged array
      // new joined parent so create new singleton pointing to it, a'
      PredictionContext a_ = SingletonPredictionContext.create(parent, a.returnState);
      if (mergeCache != null) mergeCache.put(a, b, a_);
      return a_;
    } else { // a != b payloads differ
      // see if we can collapse parents due to $+x parents if local ctx
      PredictionContext singleParent = null;
      if (a == b || (a.parent != null && a.parent == b.parent)) { // ax + bx = [a,b]x
        singleParent = a.parent;
      }
      if (singleParent != null) { // parents are same
        // sort payloads and use same parent
        List<int> payloads = [a.returnState, b.returnState];
        if (a.returnState > b.returnState) {
          payloads[0] = b.returnState;
          payloads[1] = a.returnState;
        }
        List<PredictionContext> parents = [singleParent, singleParent];
        PredictionContext a_ = new ListPredictionContext(parents, payloads);
        if (mergeCache != null) mergeCache.put(a, b, a_);
        return a_;
      }
      // parents differ and can't merge them. Just pack together
      // into array; can't merge.
      // ax + by = [ax,by]
      List<int> payloads = [a.returnState, b.returnState];
      List<PredictionContext> parents = [a.parent, b.parent];
      if (a.returnState > b.returnState) { // sort by payload
        payloads[0] = b.returnState;
        payloads[1] = a.returnState;
        parents = <PredictionContext>[b.parent, a.parent];
      }
      PredictionContext a_ = new ListPredictionContext(parents, payloads);
      if (mergeCache != null) mergeCache.put(a, b, a_);
      return a_;
    }
  }

  /// Handle case where at least one of `a` or `b` is [EMPTY]. In
  /// the following diagrams, the symbol `$` is used to represent [EMPTY].
  ///
  /// [a] is the first [SingletonPredictionContext]
  /// [b] is the second [SingletonPredictionContext]
  /// [rootIsWildcard] `true` if this is a local-context merge,
  /// otherwise `false` to indicate a full-context merge
  static PredictionContext mergeRoot(
                        SingletonPredictionContext a,
                        SingletonPredictionContext b,
                        bool rootIsWildcard) {
    if (rootIsWildcard) {
      if (a == EMPTY) return EMPTY;  // * + b = *
      if (b == EMPTY) return EMPTY;  // a + * = *
    } else {
      if (a == EMPTY && b == EMPTY) return EMPTY; // $ + $ = $
      if (a == EMPTY) { // $ + x = [$,x]
        List<int> payloads = [b.returnState, EMPTY_RETURN_STATE];
        List<PredictionContext> parents = [b.parent, null];
        var joined = new ListPredictionContext(parents, payloads);
        return joined;
      }
      if (b == EMPTY) { // x + $ = [$,x] ($ is always first if present)
        List<int> payloads = [a.returnState, EMPTY_RETURN_STATE];
        List<PredictionContext> parents = [a.parent, null];
        var joined = new ListPredictionContext(parents, payloads);
        return joined;
      }
    }
    return null;
  }

  /// Merge two [ListPredictionContext] instances.
  static PredictionContext mergeLists(
        ListPredictionContext a,
        ListPredictionContext b,
        bool rootIsWildcard,
        DoubleKeyMap<PredictionContext,PredictionContext,PredictionContext> mergeCache) {
    if (mergeCache != null) {
      PredictionContext previous = mergeCache.get(a,b);
      if (previous != null) return previous;
      previous = mergeCache.get(b,a);
      if (previous != null) return previous;
    }
    // merge sorted payloads a + b => M
    int i = 0; // walks a
    int j = 0; // walks b
    int k = 0; // walks target M array
    List<int> mergedReturnStates = new List<int>(a.returnStates.length + b.returnStates.length);
    var mergedParents = new List<PredictionContext>(a.returnStates.length + b.returnStates.length);
    // walk and merge to yield mergedParents, mergedReturnStates
    while (i < a.returnStates.length && j < b.returnStates.length) {
      PredictionContext a_parent = a.parents[i];
      PredictionContext b_parent = b.parents[j];
      if (a.returnStates[i] == b.returnStates[j]) {
        // same payload (stack tops are equal), must yield merged singleton
        int payload = a.returnStates[i];
        // $+$ = $
        bool both$ = payload == EMPTY_RETURN_STATE && a_parent == null && b_parent == null;
        bool ax_ax = (a_parent != null && b_parent != null) && a_parent == b_parent; // ax+ax -> ax
        if (both$ || ax_ax) {
          mergedParents[k] = a_parent; // choose left
          mergedReturnStates[k] = payload;
        } else { // ax+ay -> a'[x,y]
          var mergedParent = merge(a_parent, b_parent, rootIsWildcard, mergeCache);
          mergedParents[k] = mergedParent;
          mergedReturnStates[k] = payload;
        }
        i++; // hop over left one as usual
        j++; // but also skip one in right side since we merge
      } else if (a.returnStates[i] < b.returnStates[j]) { // copy a[i] to M
        mergedParents[k] = a_parent;
        mergedReturnStates[k] = a.returnStates[i];
        i++;
      } else { // b > a, copy b[j] to M
        mergedParents[k] = b_parent;
        mergedReturnStates[k] = b.returnStates[j];
        j++;
      }
      k++;
    }
    // copy over any payloads remaining in either array
    if (i < a.returnStates.length) {
      for (int p = i; p < a.returnStates.length; p++) {
        mergedParents[k] = a.parents[p];
        mergedReturnStates[k] = a.returnStates[p];
        k++;
      }
    } else {
      for (int p = j; p < b.returnStates.length; p++) {
        mergedParents[k] = b.parents[p];
        mergedReturnStates[k] = b.returnStates[p];
        k++;
      }
    }
    // trim merged if we combined a few that had same stack tops
    if (k < mergedParents.length) { // write index < last position; trim
      if (k == 1) { // for just one merged element, return singleton top
        var a_ = SingletonPredictionContext.create(
                            mergedParents[0],
                            mergedReturnStates[0]);
        if (mergeCache != null) mergeCache.put(a, b, a_);
        return a_;
      }
      mergedParents = mergedParents.getRange(0, k).toList();
      mergedReturnStates = mergedReturnStates.getRange(0, k).toList();
    }
    var M = new ListPredictionContext(mergedParents, mergedReturnStates);
    if (M == a) {
      if (mergeCache != null) mergeCache.put(a, b, a);
      return a;
    }
    if (M == b) {
      if (mergeCache != null) mergeCache.put(a, b, b);
      return b;
    }
    _combineCommonParents(mergedParents);
    if (mergeCache != null) mergeCache.put(a, b, M);
    return M;
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

  static PredictionContext getCachedContext(
                    PredictionContext context,
                    PredictionContextCache contextCache,
                    HashMap<PredictionContext, PredictionContext> visited) {
    if (context.isEmpty) return context;
    PredictionContext existing = visited[context];
    if (existing != null) return existing;
    existing = contextCache.get(context);
    if (existing != null) {
      visited[context] = existing;
      return existing;
    }
    bool changed = false;
    List<PredictionContext> parents = new List<PredictionContext>(context.length);
    for (int i = 0; i < parents.length; i++) {
      PredictionContext parent = getCachedContext(context.getParent(i), contextCache, visited);
      if (changed || parent != context.getParent(i)) {
        if (!changed) {
          parents = new List<PredictionContext>(context.length);
          for (int j = 0; j < context.length; j++) {
            parents[j] = context.getParent(j);
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
      updated = SingletonPredictionContext.create(parents[0], context.getReturnState(0));
    } else {
      ListPredictionContext listPredictionContext = context;
      updated = new ListPredictionContext(parents, listPredictionContext.returnStates);
    }
    contextCache.add(updated);
    visited[updated] = updated;
    visited[context] = updated;
    return updated;
  }

  static List<PredictionContext> getAllContextNodes(
                PredictionContext context,
                [List<PredictionContext> nodes,
                Map<PredictionContext, PredictionContext> visited]) {
    nodes = (nodes != null) ? nodes : new List<PredictionContext>();
    visited = (visited != null) ? visited : new HashMap<PredictionContext, PredictionContext>();
    if (!(context == null || visited.containsKey(context))) {;
      visited[context] = context;
      nodes.add(context);
      for (int i = 0; i < context.length; i++) {
        getAllContextNodes(context.getParent(i), nodes, visited);
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
      PredictionContext p = this;
      int stateNumber = currentState;
      StringBuffer localBuffer = new StringBuffer("[");
      while (!p.isEmpty && p != stop) {
        int index = 0;
        if (p.length > 0) {
          int bits = 1;
          while ((1 << bits) < p.length) bits++;
          int mask = (1 << bits) - 1;
          index = (perm >> offset) & mask;
          last = last && (index >= p.length - 1);
          if (index >= p.length) continue outer;
          offset += bits;
        }
        if (recognizer != null) {
          if (localBuffer.length > 1) {
            localBuffer.write(' ');
          }
          Atn atn = recognizer.atn;
          AtnState s = atn.states[stateNumber];
          String ruleName = recognizer.ruleNames[s.ruleIndex];
          localBuffer.write(ruleName);
        } else if (p.getReturnState(index) != EMPTY_RETURN_STATE) {
          if (!p.isEmpty) {
            if (localBuffer.length > 1) {
              // first char is '[', if more than that this isn't the first rule
              localBuffer.write(' ');
            }
            localBuffer.write(p.getReturnState(index));
          }
        }
        stateNumber = p.getReturnState(index);
        p = p.getParent(index);
      }
      localBuffer.write("]");
      result.add(localBuffer.toString());
      if (last) break;
    }
    return result;
  }
}
