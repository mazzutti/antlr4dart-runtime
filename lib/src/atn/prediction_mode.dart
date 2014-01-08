part of antlr4dart;

class PredictionMode {

  /**
   * Do only local context prediction (SLL style) and using
   * heuristic which almost always works but is much faster
   * than precise answer.
   */
  static const PredictionMode SLL = const PredictionMode._internal("SLL");

  /**
   * Full LL(*) that always gets right answer. For speed
   * reasons, we terminate the prediction process when we know for
   * sure which alt to predict. We don't always know what
   * the ambiguity is in this mode.
   */
  static const PredictionMode LL = const PredictionMode._internal("LL");

  /**
   * Tell the full LL prediction algorithm to pursue lookahead until
   * it has uniquely predicted an alternative without conflict or it's
   * certain that it's found an ambiguous input sequence.  when this
   * variable is false. When true, the prediction process will
   * continue looking for the exact ambiguous sequence even if
   * it has already figured out which alternative to predict.
   */
  static const PredictionMode LL_EXACT_AMBIG_DETECTION =
      const PredictionMode._internal("LL_EXACT_AMBIG_DETECTION");

  final String name;

  const PredictionMode._internal(this.name);

  /**
   * Computes the SLL prediction termination condition.
   *
   * This method computes the SLL prediction termination condition for
   * both of the following cases:
   *
   * * the usual SLL+LL fallback upon SLL conflict;
   * * pure SLL without LL fallback.
   *
   * **COMBINED SLL+LL PARSING**
   *
   * When LL-fallback is enabled upon SLL conflict, correct predictions are
   * ensured regardless of how the termination condition is computed by this
   * method. Due to the substantially higher cost of LL prediction, the
   * prediction should only fall back to LL when the additional lookahead
   * cannot lead to a unique SLL prediction.
   *
   * Assuming combined SLL+LL parsing, an SLL configuration set with only
   * conflicting subsets should fall back to full LL, even if the
   * configuration sets don't resolve to the same alternative (e.g.
   * `{1,2}` and `{3,4}`. If there is at least one non-conflicting
   * configuration, SLL could continue with the hopes that more lookahead will
   * resolve via one of those non-conflicting configurations.
   *
   * Here's the prediction termination rule them: SLL (for SLL+LL parsing)
   * stops when it sees only conflicting configuration subsets. In contrast,
   * full LL keeps going when there is uncertainty.
   *
   * **HEURISTIC**
   *
   * As a heuristic, we stop prediction when we see any conflicting subset
   * unless we see a state that only has one alternative associated with it.
   * The single-alt-state thing lets prediction continue upon rules like
   * (otherwise, it would admit defeat too soon):
   *
   *
   * `[12|1|[], 6|2|[], 12|2|[]]. s : (ID | ID ID?) ';' ;`
   *
   *
   * When the ATN simulation reaches the state before `';'`, it has a
   * DFA state that looks like: `[12|1|[], 6|2|[], 12|2|[]]`. Naturally
   * `12|1|[]` and `12|2|[]` conflict, but we cannot stop
   * processing this node because alternative to has another way to continue,
   * via `[6|2|[]]`.
   *
   * It also let's us continue for this rule:
   *
   * `[1|1|[], 1|2|[], 8|3|[]] a : A | A | A B ;`
   *
   * After matching input A, we reach the stop state for rule A, state 1.
   * State 8 is the state right before B. Clearly alternatives 1 and 2
   * conflict and no amount of further lookahead will separate the two.
   * However, alternative 3 will be able to continue and so we do not stop
   * working on this state. In the previous example, we're concerned with
   * states associated with the conflicting alternatives. Here alt 3 is not
   * associated with the conflicting configs, but since we can continue
   * looking for input reasonably, don't declare the state done.
   *
   *
   * **PURE SLL PARSING**
   *
   * To handle pure SLL parsing, all we have to do is make sure that we
   * combine stack contexts for configurations that differ only by semantic
   * predicate. From there, we can do the usual SLL termination heuristic.
   *
   * **PREDICATES IN SLL+LL PARSING**
   *
   *
   * SLL decisions don't evaluate predicates until after they reach DFA stop
   * states because they need to create the DFA cache that works in all
   * semantic situations. In contrast, full LL evaluates predicates collected
   * during start state computation so it can ignore predicates thereafter.
   * This means that SLL termination detection can totally ignore semantic
   * predicates.
   *
   *
   * Implementation-wise, [AtnConfigSet] combines stack contexts but not
   * semantic predicate contexts so we might see two configurations like the
   * following.
   *
   * `(s, 1, x, {}), (s, 1, x', {p})`
   *
   *
   * Before testing these configurations against others, we have to merge
   * `x` and `x'` (without modifying the existing configurations).
   * For example, we test `(x+x') == x''` when looking for conflicts in
   * the following configurations.
   *
   * `(s, 1, x, {}), (s, 1, x', {p}), (s, 2, x'', {})`
   *
   * If the configuration set has predicates (as indicated by
   * [AtnConfigSet.hasSemanticContext]), this algorithm makes a copy of
   * the configurations to strip out all of the predicates so that a standard
   * [AtnConfigSet] will merge everything ignoring predicates.
   */
  static bool hasSllConflictTerminatingPrediction(PredictionMode mode, AtnConfigSet configs) {
    // Configs in rule stop states indicate reaching the end of the decision
    // rule (local context) or end of start rule (full context). If all
    // configs meet this condition, then none of the configurations is able
    // to match additional input so we terminate prediction.

    if (allConfigsInRuleStopStates(configs)) return true;
    // pure SLL mode parsing
    if (mode == PredictionMode.SLL) {
      // Don't bother with combining configs from different semantic
      // contexts if we can fail over to full LL; costs more time
      // since we'll often fail over anyway.
      if (configs.hasSemanticContext) {
        // dup configs, tossing out semantic predicates
        AtnConfigSet dup = new AtnConfigSet();
        for (AtnConfig c in configs) {
          c = new AtnConfig.from(c, semanticContext:SemanticContext.NONE);
          dup.add(c);
        }
        configs = dup;
      }
      // now we have combined contexts for configs with dissimilar preds
    }
    // pure SLL or combined SLL+LL mode parsing
    Iterable<BitSet> altsets = getConflictingAltSubsets(configs);
    return hasConflictingAltSet(altsets) && !hasStateAssociatedWithOneAlt(configs);
  }

  /**
   * Checks if any configuration in `configs` is in a
   * [RuleStopState]. Configurations meeting this condition have reached
   * the end of the decision rule (local context) or end of start rule (full
   * context).
   *
   * [configs] is the configuration set to test.
   * Return `true` if any configuration in `configs` is in a
   * [RuleStopState], otherwise `false`.
   */
  static bool hasConfigInRuleStopState(AtnConfigSet configs) {
    for (AtnConfig c in configs) {
      if (c.state is RuleStopState) {
        return true;
      }
    }
    return false;
  }

  /**
   * Checks if all configurations in `configs` are in a
   * [RuleStopState]. Configurations meeting this condition have reached
   * the end of the decision rule (local context) or end of start rule (full
   * context).
   *
   * [configs] is the configuration set to test.
   * Return `true` if all configurations in `configs` are in a
   * [RuleStopState], otherwise `false`.
   */
  static bool allConfigsInRuleStopStates(AtnConfigSet configs) {
    for (AtnConfig config in configs) {
      if (config.state is! RuleStopState) {
        return false;
      }
    }
    return true;
  }

  /**
   * Full LL prediction termination.
   *
   * Can we stop looking ahead during ATN simulation or is there some
   * uncertainty as to which alternative we will ultimately pick, after
   * consuming more input? Even if there are partial conflicts, we might know
   * that everything is going to resolve to the same minimum alternative. That
   * means we can stop since no more lookahead will change that fact. On the
   * other hand, there might be multiple conflicts that resolve to different
   * minimums. That means we need more look ahead to decide which of those
   * alternatives we should predict.
   *
   * The basic idea is to split the set of configurations `C`, into
   * conflicting subsets `(s, _, ctx, _)` and singleton subsets with
   * non-conflicting configurations. Two configurations conflict if they have
   * identical [AtnConfig.state] and [AtnConfig.context] values
   * but different [AtnConfig.alt] value, e.g. `(s, i, ctx, _)`
   * and `(s, j, ctx, _)` for `i != j`.
   *
   * Reduce these configuration subsets to the set of possible alternatives.
   * You can compute the alternative subsets in one pass as follows:
   *
   * `A_s,ctx = {i | (s, i, ctx, _)}` for each configuration in
   * `C` holding `s` and `ctx` fixed.
   *
   * Or in pseudo-code, for each configuration `c` in `C`:
   *
   * `map[c] U= c.alt` // map hash/equals uses s and x, not alt and not pred
   *
   * The values in `map` are the set of `A_s,ctx` sets.
   *
   * If `|A_s,ctx|=1` then there is no conflict associated with `s` and `ctx`.
   *
   * Reduce the subsets to singletons by choosing a minimum of each subset. If
   * the union of these alternative subsets is a singleton, then no amount of
   * more lookahead will help us. We will always pick that alternative. If,
   * however, there is more than one alternative, then we are uncertain which
   * alternative to predict and must continue looking for resolution. We may
   * or may not discover an ambiguity in the future, even if there are no
   * conflicting subsets this round.
   *
   * The biggest sin is to terminate early because it means we've made a
   * decision but were uncertain as to the eventual outcome. We haven't used
   * enough lookahead. On the other hand, announcing a conflict too late is no
   * big deal; you will still have the conflict. It's just inefficient. It
   * might even look until the end of file.
   *
   * No special consideration for semantic predicates is required because
   * predicates are evaluated on-the-fly for full LL prediction, ensuring that
   * no configuration contains a semantic context during the termination
   * check.
   *
   * **CONFLICTING CONFIGS**
   *
   * Two configurations `(s, i, x)` and `(s, j, x')`, conflict
   * when `i! = j` but `x = x'`. Because we merge all `(s, i, _)`
   * configurations together, that means that there are at
   * most `n` configurations associated with state `s` for
   * `n` possible alternatives in the decision. The merged stacks
   * complicate the comparison of configuration contexts `x` and
   * `x'`. Sam checks to see if one is a subset of the other by calling
   * merge and checking to see if the merged result is either `x` or
   * `x'`. If the `x` associated with lowest alternative `i`
   * is the superset, then `i` is the only possible prediction since the
   * others resolve to `min(i)` as well. However, if `x` is
   * associated with `j > i` then at least one stack configuration for
   * `j` is not in conflict with alternative `i`. The algorithm
   * should keep going, looking for more lookahead due to the uncertainty.
   *
   * For simplicity, I'm doing a equality check between `x` and
   * `x'` that lets the algorithm continue to consume lookahead longer
   * than necessary. The reason I like the equality is of course the
   * simplicity but also because that is the test you need to detect the
   * alternatives that are actually in conflict.
   *
   * **CONTINUE/STOP RULE**
   *
   * Continue if union of resolved alternative sets from non-conflicting and
   * conflicting alternative subsets has more than one alternative. We are
   * uncertain about which alternative to predict.
   *
   * The complete set of alternatives, `[i for (_,i,_)]`, tells us which
   * alternatives are still in the running for the amount of input we've
   * consumed at this point. The conflicting sets let us to strip away
   * configurations that won't lead to more states because we resolve
   * conflicts to the configuration with a minimum alternate for the
   * conflicting set.
   *
   * **CASES**
   *
   * * no conflicts and more than 1 alternative in set =>; continue
   * * `(s, 1, x)`, `(s, 2, x)`, `(s, 3, z)`, `(s', 1, y)`, `(s', 2, y)`
   *   yields non-conflicting set `{3}` U conflicting sets `min({1,2})`
   *   U `min({1,2})` = `{1,3}` =>; continue
   * * `(s, 1, x)`, `(s, 2, x)`, `(s', 1, y)`, `(s', 2, y)`, `(s'', 1, z)`
   *   yields non-conflicting set `{1}` U conflicting sets `min({1,2})`
   *   U `min({1,2})` = `{1}` =>; stop and predict 1
   * * `(s, 1, x)`, `(s, 2, x)`, `(s', 1, y)`, `(s', 2, y)` yields
   *   conflicting, reduced sets `{1}` U `{1}` = `{1}` =>; stop and
   *   predict 1, can announce ambiguity `{1,2}`
   * * `(s, 1, x)`, `(s, 2, x)`, `(s', 2, y)`, `(s', 3, y)` yields
   *   conflicting, reduced sets `{1}` U `{2}` = `{1,2}` =>; continue
   * * `(s, 1, x)`, `(s, 2, x)`, `(s', 3, y)`, `(s', 4, y)` yields
   *   conflicting, reduced sets `{1}` U `{3}` = `{1,3}` =>; continue
   *
   * **EXACT AMBIGUITY DETECTION**
   *
   * If all states report the same conflicting set of alternatives, then we
   * know we have the exact ambiguity set.
   *
   * `|A_i|>1` and `A_i = A_j` for all `i`, `j`.
   *
   * In other words, we continue examining lookahead until all `A_i`
   * have more than one alternative and all `A_i` are the same. If
   * `A={{1,2}, {1,3}}`, then regular LL prediction would terminate
   * because the resolved set is `{1}`. To determine what the real
   * ambiguity is, we have to know whether the ambiguity is between one and
   * two or one and three so we keep going. We can only stop prediction when
   * we need exact ambiguity detection when the sets look like
   * `A={{1,2}}` or `{{1,2},{1,2}}`, etc...
   */
  static int resolvesToJustOneViableAlt(Iterable<BitSet> altsets) {
    return getSingleViableAlt(altsets);
  }

  /**
   * Determines if every alternative subset in `altsets` contains more
   * than one alternative.
   *
   * [altsets] is a collection of alternative subsets.
   * Return `true` if every [BitSet] in `altsets` has
   * [BitSet.cardinality] > 1, otherwise `false`.
   */
  static bool allSubsetsConflict(Iterable<BitSet> altsets) {
    return !hasNonConflictingAltSet(altsets);
  }

  /**
   * Determines if any single alternative subset in `altsets` contains
   * exactly one alternative.
   *
   * [altsets] is a collection of alternative subsets.
   * Return `true` if `altsets` contains a [BitSet] with
   * [BitSet.cardinality] 1, otherwise `false`.
   */
  static bool hasNonConflictingAltSet(Iterable<BitSet> altsets) {
    for (BitSet alts in altsets) {
      if (alts.cardinality == 1) {
        return true;
      }
    }
    return false;
  }

  /**
   * Determines if any single alternative subset in `altsets` contains
   * more than one alternative.
   *
   * [altsets] is a collection of alternative subsets.
   * Return `true` if `altsets` contains a [BitSet] with
   * [BitSet.cardinality] > 1, otherwise `false`.
   */
  static bool hasConflictingAltSet(Iterable<BitSet> altsets) {
    for (BitSet alts in altsets) {
      if (alts.cardinality > 1) {
        return true;
      }
    }
    return false;
  }

  /**
   * Determines if every alternative subset in `altsets` is equivalent.
   *
   * [altsets] is a collection of alternative subsets.
   * Return `true` if every member of `altsets` is equal to the
   * others, otherwise `false`.
   */
  static bool allSubsetsEqual(Iterable<BitSet> altsets) {
    Iterator<BitSet> it = altsets.iterator;
    it.moveNext();
    BitSet first = it.current;
    while (it.moveNext()) {
      BitSet next = it.current;
      if (next != first) return false;
    }
    return true;
  }

  /**
   * Returns the unique alternative predicted by all alternative subsets in
   * `altsets`. If no such alternative exists, this method returns
   * [Atn.INVALID_ALT_NUMBER].
   *
   * [altsets] is a collection of alternative subsets.
   */
  static int getUniqueAlt(Iterable<BitSet> altsets) {
    BitSet all = getAlts(altsets);
    if (all.cardinality == 1) return all.nextSetBit(0);
    return Atn.INVALID_ALT_NUMBER;
  }

  /**
   * Gets the complete set of represented alternatives for a collection of
   * alternative subsets. This method returns the union of each [BitSet]
   * in `altsets`.
   *
   * [altsets] is a collection of alternative subsets.
   * Return the set of represented alternatives in `altsets`.
   */
  static BitSet getAlts(Iterable<BitSet> altsets) {
    BitSet all = new BitSet();
    for (BitSet alts in altsets) {
      all.or(alts);
    }
    return all;
  }

  /**
   * This function gets the conflicting alt subsets from a configuration set.
   * For each configuration `c` in `configs`:
   *
   *      map[c] U= c.alt // map hash/equals uses s and x, not alt and not pred
   */
  static Iterable<BitSet> getConflictingAltSubsets(AtnConfigSet configs) {
    var configToAlts = new HashMap(equals:_equals, hashCode:_hashCode);
    for (AtnConfig c in configs) {
      BitSet alts = configToAlts[c];
      if (alts == null) {
        alts = new BitSet();
        configToAlts[c] = alts;
      }
      alts.set(c.alt, true);
    }
    return configToAlts.values;
  }

  /**
   * Get a map from state to alt subset from a configuration set. For each
   * configuration `c` in `configs`:
   *
   *      map[c.state] U= c.alt alt
   */
  static Map<AtnState, BitSet> getStateToAltMap(AtnConfigSet configs) {
    Map<AtnState, BitSet> m = new HashMap<AtnState, BitSet>();
    for (AtnConfig c in configs) {
      BitSet alts = m[c.state];
      if (alts == null) {
        alts = new BitSet();
        m[c.state] = alts;
      }
      alts.set(c.alt, true);
    }
    return m;
  }

  static bool hasStateAssociatedWithOneAlt(AtnConfigSet configs) {
    Map<AtnState, BitSet> x = getStateToAltMap(configs);
    for (BitSet alts in x.values) {
      if (alts.cardinality == 1) return true;
    }
    return false;
  }

  static int getSingleViableAlt(Iterable<BitSet> altsets) {
    BitSet viableAlts = new BitSet();
    for (BitSet alts in altsets) {
      int minAlt = alts.nextSetBit(0);
      viableAlts.set(minAlt, true);
      if (viableAlts.cardinality > 1) { // more than 1 viable alt
        return Atn.INVALID_ALT_NUMBER;
      }
    }
    return viableAlts.nextSetBit(0);
  }

  String toString() => name;

  bool operator==(Object other) {
    if (other is! PredictionMode) return false;
    return name == (other as PredictionMode).name;
  }
}

/** Code is function of (s, _, ctx, _) */
int _hashCode(AtnConfig o) {
  int hashCode = MurmurHash.initialize(7);
  hashCode = MurmurHash.update(hashCode, o.state.stateNumber);
  hashCode = MurmurHash.update(hashCode, o.context.hashCode);
  hashCode = MurmurHash.finish(hashCode, 2);
  return hashCode;
}

bool _equals(AtnConfig a, AtnConfig b) {
  if (a == b) return true;
  if (a == null || b == null) return false;
  return a.state.stateNumber == b.state.stateNumber
    && a.context == b.context;
}
