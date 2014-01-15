part of antlr4dart;

abstract class AtnSimulator {

  /**
   * Must distinguish between missing edge and edge we know leads nowhere
   */
  static final DfaState ERROR = () {
    var dfa = new DfaState.config(new AtnConfigSet());
    dfa.stateNumber = pow(2, 53) - 1;
    return dfa;
  }();

  final Atn atn;

  /**
   * The context cache maps all [PredictionContext] objects that are `==`
   * to a single cached copy. This cache is shared across all contexts
   * in all [AtnConfig]s in all DFA states.  We rebuild each [AtnConfigSet]
   * to use only cached nodes/graphs in `addDfaState()`. We don't want to
   * fill this during `closure()` since there are lots of contexts that
   * pop up but are not used ever again. It also greatly slows down `closure()`.
   */
  final PredictionContextCache _sharedContextCache;

  AtnSimulator(this.atn, this._sharedContextCache);

  void reset();

  PredictionContextCache get sharedContextCache {
    return _sharedContextCache;
  }

  PredictionContext getCachedContext(PredictionContext context) {
    if (_sharedContextCache == null) return context;
    var visited = new HashMap<PredictionContext, PredictionContext>();
    return PredictionContext.getCachedContext(context, sharedContextCache, visited);
  }

  static Atn deserialize(String data) {
    return new AtnDeserializer().deserialize(data);
  }
}
