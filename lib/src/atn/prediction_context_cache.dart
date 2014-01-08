part of antlr4dart;

/**
 * Used to cache [PredictionContext] objects. Its used for the shared
 * context cash associated with contexts in DFA states. This cache
 * can be used for both lexers and parsers.
 */
class PredictionContextCache {
  Map<PredictionContext, PredictionContext> _cache =
    new HashMap<PredictionContext, PredictionContext>();

  /**
   * Add a context to the cache and return it. If the context already exists,
   * return that one instead and do not add a new context to the cache.
   * Protect shared cache from unsafe thread access.
   */
  PredictionContext add(PredictionContext ctx) {
    if (ctx == PredictionContext.EMPTY) return PredictionContext.EMPTY;
    PredictionContext existing = _cache[ctx];
    if (existing != null) return existing;
    _cache[ctx] = ctx;
    return ctx;
  }

  PredictionContext get(PredictionContext ctx) {
    return _cache[ctx];
  }

  int get length => _cache.length;
}
