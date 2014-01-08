part of antlr4dart;

class LexerDfaSerializer extends DfaSerializer {
  LexerDfaSerializer(Dfa dfa) : super(dfa, null);
  String _getEdgeLabel(int i) => "'${new String.fromCharCode(i)}'";
}
