part of antlr4dart;

class LexerInterpreter extends Lexer {
  final String grammarFileName;
  final Atn atn;

  final List<String> tokenNames;
  final List<String> ruleNames;
  final List<String> modeNames;

  final List<Dfa> decisionToDfa;
  final PredictionContextCache sharedContextCache = new PredictionContextCache();

  LexerInterpreter(this.grammarFileName,
                   this.tokenNames,
                   this.ruleNames,
                   this.modeNames,
                   Atn atn, CharSource input) : super(input),
    decisionToDfa = new List<Dfa>(atn.numberOfDecisions),
    this.atn = atn {
    if (atn.grammarType != AtnType.LEXER) {
      throw new ArgumentError("The ATN must be a lexer ATN.");
    }
    for (int i = 0; i < decisionToDfa.length; i++) {
      decisionToDfa[i] = new Dfa(atn.getDecisionState(i), i);
    }
    interpreter = new LexerAtnSimulator(atn, decisionToDfa, sharedContextCache, this);
  }
}
