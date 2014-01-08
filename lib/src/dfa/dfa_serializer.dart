part of antlr4dart;

/**
 * A DFA walker that knows how to dump them to serialized strings.
 */
class DfaSerializer {
  final Dfa dfa;
  final List<String> tokenNames;

  DfaSerializer(this.dfa, this.tokenNames);

  String toString() {
    if (dfa.s0 == null) return null;
    StringBuffer buf = new StringBuffer();
    List<DfaState> states = dfa.orderedStates;
    for (DfaState s in states) {
      int n = 0;
      if (s.edges != null) n = s.edges.length;
      for (int i = 0; i < n; i++) {
        DfaState t = s.edges[i];
        if (t != null && t.stateNumber < pow(2, 53) - 1) {
          buf.write(_getStateString(s));
          String label = _getEdgeLabel(i);
          buf..write("-")
            ..write(label)
            ..write("->")
            ..writeln(_getStateString(t));
        }
      }
    }
    return buf.toString();
  }

  String _getEdgeLabel(int i) {
    String label;
    if (i == 0) return "EOF";
    if (tokenNames != null) label = tokenNames[i-1];
    else label = new String.fromCharCode(i);
    return label;
  }

  String _getStateString(DfaState s) {
    int n = s.stateNumber;
    final String baseStateStr = "${s.isAcceptState
      ? ':' : ''}s$n${s.requiresFullContext ? '^' : ''}";
    if (s.isAcceptState) {
      if (s.predicates != null) {
        return "$baseStateStr=>${s.predicates}";
      } else {
        return "$baseStateStr=>${s.prediction}";
      }
    } else {
      return baseStateStr;
    }
  }
}
