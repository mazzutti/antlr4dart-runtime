part of antlr4dart;

///  and tree parsers.
class DefaultErrorStrategy implements ErrorStrategy {

  // This is true after we see an error and before having successfully
  // matched a token. Prevents generation of more than one error message
  // per error.
  bool _errorRecoveryMode = false;

  // The index into the input source where the last error occurred.
  // This is used to prevent infinite loops where an error is found
  // but no token is consumed during recovery...another error is found,
  // ad nauseum.  This is a failsafe mechanism to guarantee that at least
  // one token/tree node is consumed for two errors.
  int _lastErrorIndex = -1;

  IntervalSet _lastErrorStates;

  /// The default implementation simply ensure that the handler is not
  /// in error recovery mode.
  void reset(Parser recognizer) {
    _endErrorCondition(recognizer);
  }

  /// This method is called to enter error recovery mode when a recognition
  /// exception is reported.
  ///
  /// [recognizer] is the parser instance.
  void beginErrorCondition(Parser recognizer) {
    _errorRecoveryMode = true;
  }

  bool inErrorRecoveryMode(Parser recognizer) {
    return _errorRecoveryMode;
  }

  IntervalSet getExpectedTokens(Parser recognizer) {
    return recognizer.expectedTokens;
  }

  void reportMatch(Parser recognizer) {
    _endErrorCondition(recognizer);
  }

  /// The default implementation returns immediately if the handler is already
  /// in error recovery mode. Otherwise, it calls [beginErrorCondition]
  /// and dispatches the reporting task based on the runtime type of `e`
  /// according to the following table:
  ///
  /// * [NoViableAltException]: Dispatches the call to [_reportNoViableAlternative]
  /// * [InputMismatchException]: Dispatches the call to [_reportInputMismatch]
  /// * FailedPredicateException]: Dispatches the call to [_reportFailedPredicate]
  /// * All other types: calls [Parser.notifyErrorListeners] to report the exception
  void reportError(Parser recognizer, RecognitionException e) {
    // if we've already reported an error and have not matched a token
    // yet successfully, don't report any errors.
    if (inErrorRecoveryMode(recognizer)) {
      return; // don't report spurious errors
    }
    beginErrorCondition(recognizer);
    if (e is NoViableAltException) {
      _reportNoViableAlternative(recognizer, e);
    } else if (e is InputMismatchException) {
      _reportInputMismatch(recognizer, e);
    } else if (e is FailedPredicateException) {
      _reportFailedPredicate(recognizer, e);
    } else {
      print("unknown recognition error type: ${e.runtimeType}");
      recognizer.notifyErrorListeners(e.message, e.offendingToken, e);
    }
  }

  /// The default implementation resynchronizes the parser by consuming tokens
  /// until we find one in the resynchronization set--loosely the set of tokens
  /// that can follow the current rule.
  void recover(Parser recognizer, RecognitionException e) {
    if (_lastErrorIndex == recognizer.inputSource.index &&
      _lastErrorStates != null && _lastErrorStates.contains(recognizer.state)) {
      // uh oh, another error at same token index and previously-visited
      // state in ATN; must be a case where LT(1) is in the recovery
      // token set so nothing got consumed. Consume a single token
      // at least to prevent an infinite loop; this is a failsafe.
      recognizer.consume();
    }
    _lastErrorIndex = recognizer.inputSource.index;
    if (_lastErrorStates == null) _lastErrorStates = new IntervalSet();
    _lastErrorStates.addSingle(recognizer.state);
    IntervalSet followSet = _getErrorRecoverySet(recognizer);
    _consumeUntil(recognizer, followSet);
  }

  /// The default implementation of [ErrorStrategy.sync] makes sure
  /// that the current lookahead symbol is consistent with what were expecting
  /// at this point in the ATN. You can call this anytime but antlr4dart only
  /// generates code to check before subrules/loops and each iteration.
  ///
  /// Implements Jim Idle's magic sync mechanism in closures and optional
  /// subrules. E.g.,
  ///
  ///      a : sync ( stuff sync )* ;
  ///      sync : {consume to what can follow sync} ;
  ///
  /// At the start of a sub rule upon error, `sync` performs single
  /// token deletion, if possible. If it can't do that, it bails on the current
  /// rule and uses the default error recovery, which consumes until the
  /// resynchronization set of the current rule.
  ///
  /// If the sub rule is optional (`(...)?`, `(...)*`, or block
  /// with an empty alternative), then the expected set includes what follows
  /// the subrule.
  ///
  /// During loop iteration, it consumes until it sees a token that can start a
  /// sub rule or what follows loop. Yes, that is pretty aggressive. We opt to
  /// stay in the loop as long as possible.
  ///
  /// **ORIGINS**
  ///
  /// Previous versions of ANTLR did a poor job of their recovery within loops.
  /// A single mismatch token or missing token would force the parser to bail
  /// out of the entire rules surrounding the loop. So, for rule
  ///
  ///      classDef : 'class' ID '{' member* '}'
  ///
  /// input with an extra token between members would force the parser to
  /// consume until it found the next class definition rather than the next
  /// member definition of the current class.
  ///
  /// This functionality cost a little bit of effort because the parser has to
  /// compare token set at the start of the loop and at each iteration. If for
  /// some reason speed is suffering for you, you can turn off this
  /// functionality by simply overriding this method as a blank { }.
  void sync(Parser recognizer) {
    AtnState s = recognizer.interpreter.atn.states[recognizer.state];
    // If already recovering, don't try to sync
    if (inErrorRecoveryMode(recognizer)) return;
    TokenSource tokens = recognizer.inputSource;
    int la = tokens.lookAhead(1);
    // try cheaper subset first; might get lucky. seems to shave a wee bit off
    if (recognizer.atn.nextTokensInSameRule(s).contains(la) || la == Token.EOF) return;
    // Return but don't end recovery. only do that upon valid token match
    if (recognizer.isExpectedToken(la)) return;
    switch (s.stateType) {
      case AtnState.BLOCK_START:
      case AtnState.STAR_BLOCK_START:
      case AtnState.PLUS_BLOCK_START:
      case AtnState.STAR_LOOP_ENTRY:
        // report error and recover if possible
        if (_singleTokenDeletion(recognizer) != null) return;
        throw new InputMismatchException(recognizer);
      case AtnState.PLUS_LOOP_BACK:
      case AtnState.STAR_LOOP_BACK:
        _reportUnwantedToken(recognizer);
        IntervalSet expecting = recognizer.expectedTokens;
        IntervalSet whatFollowsLoopIterationOrRule =
          expecting.or(_getErrorRecoverySet(recognizer));
        _consumeUntil(recognizer, whatFollowsLoopIterationOrRule);
        break;
      default:
        // do nothing if we can't identify the exact kind of ATN state
        break;
      }
  }

  /// The default implementation attempts to recover from the mismatched input
  /// by using single token insertion and deletion as described below. If the
  /// recovery attempt fails, this method throws an [InputMismatchException].
  ///
  /// **EXTRA TOKEN** (single token deletion)
  ///
  /// `lookAhead(1)` is not what we are looking for. If `lookAhead(2)` has the
  /// right token, however, then assume `lookAhead(1)` is some extra spurious
  /// token and delete it. Then consume and return the next token (which was
  /// the `lookAhead(2)` token) as the successful result of the match operation.
  ///
  /// This recovery strategy is implemented by [singleTokenDeletion.
  ///
  /// **MISSING TOKEN** (single token insertion)
  ///
  /// If current token (at `lookAhead(1)`) is consistent with what could come
  /// after the expected `lookAhead(1)` token, then assume the token is missing
  /// and use the parser's [TokenFactory] to create it on the fly. The
  /// "insertion" is performed by returning the created token as the successful
  /// result of the match operation.
  ///
  /// This recovery strategy is implemented by [singleTokenInsertion].
  ///
  /// **EXAMPLE**
  ///
  /// For example, input `i=(3;` is clearly missing the `')'`. When
  /// the parser returns from the nested call to `expr`, it will have
  /// call chain:
  ///
  ///      stat -> expr -> atom
  ///
  /// and it will be trying to match the   ')'  at this point in the
  /// derivation:
  ///
  ///      => ID '=' '(' INT ')' ('+' atom)* ';'
  ///                    ^
  /// The attempt to match `')'` will fail when it sees `';'` and
  /// call [recoverInline]. To recover, it sees that `lookAhea(1)==';'`
  /// is in the set of tokens that can follow the `')'` token reference
  /// in rule `atom`. It can assume that you forgot the `')'`.
  Token recoverInline(Parser recognizer) {
    // SINGLE TOKEN DELETION
    Token matchedSymbol = _singleTokenDeletion(recognizer);
    if (matchedSymbol != null) {
      // we have deleted the extra token.
      // now, move past ttype token as if all were ok
      recognizer.consume();
      return matchedSymbol;
    }
    // SINGLE TOKEN INSERTION
    if (_singleTokenInsertion(recognizer)) {
      return _getMissingSymbol(recognizer);
    }
    // even that didn't work; must throw the exception
    throw new InputMismatchException(recognizer);
  }

  // This method is called to leave error recovery mode after recovering from
  // a recognition exception.
  void _endErrorCondition(Parser recognizer) {
    _errorRecoveryMode = false;
    _lastErrorStates = null;
    _lastErrorIndex = -1;
  }

  // This is called by reportError when the exception is a NoViableAltException.
  void _reportNoViableAlternative(Parser recognizer, NoViableAltException e) {
    TokenSource tokens = recognizer.inputSource;
    String input;
    if (tokens is TokenSource) {
      if (e.startToken.type == Token.EOF ) input = "<EOF>";
      else input = tokens.getText(e.startToken, e.offendingToken);
    } else {
      input = "<unknown input>";
    }
    String msg = "no viable alternative at input ${_escapeWsAndQuote(input)}";
    recognizer.notifyErrorListeners(msg, e.offendingToken, e);
  }

  // This is called by reportError when the exception is an InputMismatchException.
  void _reportInputMismatch(Parser recognizer, InputMismatchException e) {
    String msg = "mismatched input ${_getTokenErrorDisplay(e.offendingToken)}"
      " expecting ${e.expectedTokens.toTokenString(recognizer.tokenNames)}";
    recognizer.notifyErrorListeners(msg, e.offendingToken, e);
  }

  // This is called by reportError when the exception is a FailedPredicateException.
  void _reportFailedPredicate(Parser recognizer, FailedPredicateException e) {
    String ruleName = recognizer.ruleNames[recognizer.context.ruleIndex];
    String msg = "rule $ruleName ${e.message}";
    recognizer.notifyErrorListeners(msg, e.offendingToken, e);
  }

  // This method is called to report a syntax error which requires the removal
  // of a token from the input source. At the time this method is called, the
  // erroneous symbol is current lookToken(1) symbol and has not yet been
  // removed from the input source. When this method returns, recognizer
  // is in error recovery mode.
  //
  // This method is called when singleTokenDeletion identifies
  // single-token deletion as a viable recovery strategy for a mismatched
  // input error.
  //
  // The default implementation simply returns if the handler is already in
  // error recovery mode. Otherwise, it calls beginErrorCondition to
  // enter error recovery mode, followed by calling Parser.notifyErrorListeners.
  void _reportUnwantedToken(Parser recognizer) {
    if (inErrorRecoveryMode(recognizer)) return;
    beginErrorCondition(recognizer);
    Token t = recognizer.currentToken;
    String tokenName = _getTokenErrorDisplay(t);
    IntervalSet expecting = getExpectedTokens(recognizer);
    String msg = "extraneous input $tokenName expecting "
      "${expecting.toTokenString(recognizer.tokenNames)}";
    recognizer.notifyErrorListeners(msg, t, null);
  }

  // This method is called to report a syntax error which requires the
  // insertion of a missing token into the input source. At the time this
  // method is called, the missing token has not yet been inserted. When this
  // method returns, recognizer is in error recovery mode.
  //
  // This method is called when singleTokenInsertion identifies
  // single-token insertion as a viable recovery strategy for a mismatched
  // input error.
  //
  // The default implementation simply returns if the handler is already in
  // error recovery mode. Otherwise, it calls beginErrorCondition to
  // enter error recovery mode, followed by calling Parser.notifyErrorListeners.
  void _reportMissingToken(Parser recognizer) {
    if (inErrorRecoveryMode(recognizer)) return;
    beginErrorCondition(recognizer);
    Token t = recognizer.currentToken;
    IntervalSet expecting = getExpectedTokens(recognizer);
    String msg = "missing ${expecting.toTokenString(
        recognizer.tokenNames)} at ${_getTokenErrorDisplay(t)}";
    recognizer.notifyErrorListeners(msg, t, null);
  }

  // This method implements the single-token insertion inline error recovery
  // strategy. It is called by recoverInline if the single-token
  // deletion strategy fails to recover from the mismatched input. If this
  // method returns true, recognizer will be in error recovery
  // mode.
  //
  // This method determines whether or not single-token insertion is viable by
  // checking if the lookAhead(1) input symbol could be successfully matched
  // if it were instead the lookAhead(2) symbol. If this method returns
  // true, the caller is responsible for creating and inserting a
  // token with the correct type to produce this behavior.
  //
  // recognizer is the parser instance
  // Return true if single-token insertion is a viable recovery
  // strategy for the current mismatched input, otherwise false.
  bool _singleTokenInsertion(Parser recognizer) {
    int currentSymbolType = recognizer.inputSource.lookAhead(1);
    // if current token is consistent with what could come after current
    // ATN state, then we know we're missing a token; error recovery
    // is free to conjure up and insert the missing token
    AtnState currentState = recognizer.interpreter.atn.states[recognizer.state];
    AtnState next = currentState.getTransition(0).target;
    Atn atn = recognizer.interpreter.atn;
    IntervalSet expectingAtLL2 = atn.nextTokens(next, recognizer.context);
    if ( expectingAtLL2.contains(currentSymbolType) ) {
      _reportMissingToken(recognizer);
      return true;
    }
    return false;
  }

  // This method implements the single-token deletion inline error recovery
  // strategy. It is called by recoverInline to attempt to recover
  // from mismatched input. If this method returns null, the parser and error
  // handler state will not have changed. If this method returns non-null,
  // recognizer will not be in error recovery mode since the
  // returned token was a successful match.
  //
  // If the single-token deletion is successful, this method calls
  // reportUnwantedToken to report the error, followed by
  // Parser.consume to actually "delete" the extraneous token. Then,
  // before returning {@link #reportMatch} is called to signal a successful
  // match.
  //
  // recognizer is the parser instance
  // Return the successfully matched Token instance if single-token
  // deletion successfully recovers from the mismatched input, otherwise null.
  Token _singleTokenDeletion( Parser recognizer) {
    int nextTokenType = recognizer.inputSource.lookAhead(2);
    IntervalSet expecting = getExpectedTokens(recognizer);
    if ( expecting.contains(nextTokenType) ) {
      _reportUnwantedToken(recognizer);
      recognizer.consume(); // simply delete extra token
      // we want to return the token we're actually matching
      Token matchedSymbol = recognizer.currentToken;
      reportMatch(recognizer);  // we know current token is correct
      return matchedSymbol;
    }
    return null;
  }

  // Conjure up a missing token during error recovery.
  //
  // The recognizer attempts to recover from single missing
  // symbols. But, actions might refer to that missing symbol.
  // For example, x=ID {f($x);}. The action clearly assumes
  // that there has been an identifier matched previously and that
  // $x points at that token. If that token is missing, but
  // the next token in the source is what we want we assume that
  // this token is missing and we keep going. Because we
  // have to return some token to replace the missing token,
  // we have to conjure one up. This method gives the user control
  // over the tokens returned for missing tokens. Mostly,
  // you will want to create something special for identifier
  // tokens. For literals such as '{' and ',', the default
  // action in the parser or tree parser works. It simply creates
  // a CommonToken of the appropriate type. The text will be the token.
  // If you change what tokens must be created by the lexer,
  // override this method to create the appropriate tokens.
  Token _getMissingSymbol(Parser recognizer) {
    Token currentSymbol = recognizer.currentToken;
    IntervalSet expecting = getExpectedTokens(recognizer);
    int expectedTokenType = expecting.minElement; // get any element
    String tokenText;
    if ( expectedTokenType== Token.EOF ) tokenText = "<missing EOF>";
    else tokenText = "<missing ${recognizer.tokenNames[expectedTokenType]}>";
    Token current = currentSymbol;
    Token lookback = recognizer.inputSource.lookToken(-1);
    if (current.type == Token.EOF && lookback != null) {
      current = lookback;
    }
    return
      recognizer.tokenFactory(
          new Pair<TokenProvider, CharSource>(current.tokenProvider,
              current.tokenProvider.inputSource),
          expectedTokenType,
          tokenText,
          Token.DEFAULT_CHANNEL,
          -1, -1,
          current.line, current.charPositionInLine);
  }

  // How should a token be displayed in an error message? The default
  // is to display just the text, but during development you might
  // want to have a lot of information spit out.  Override in that case
  // to use t.toString() (which, for CommonToken, dumps everything about
  // the token). This is better than forcing you to override a method in
  // your token objects because you don't have to go modify your lexer
  // so that it creates a new Java type.
  String _getTokenErrorDisplay(Token t) {
    if (t == null) return "<no token>";
    String s = t.text;
    if (s == null) {
      if (t.type == Token.EOF) {
        s = "<EOF>";
      } else {
        s = "<${t.type}>";
      }
    }
    return _escapeWsAndQuote(s);
  }

  String _escapeWsAndQuote(String s) {
    s = s.replaceAll("\n","\\n");
    s = s.replaceAll("\r","\\r");
    s = s.replaceAll("\t","\\t");
    return "'$s'";
  }

  // Compute the error recovery set for the current rule.  During
  // rule invocation, the parser pushes the set of tokens that can
  // follow that rule reference on the stack; this amounts to
  // computing FIRST of what follows the rule reference in the
  // enclosing rule. See LinearApproximator.FIRST().
  // This local follow set only includes tokens
  // from within the rule; i.e., the FIRST computation done by
  // antlr4dart stops at the end of a rule.
  //
  //  EXAMPLE
  //
  //  When you find a "no viable alt exception", the input is not
  //  consistent with any of the alternatives for rule r.  The best
  //  thing to do is to consume tokens until you see something that
  //  can legally follow a call to r *or* any rule that called r.
  //  You don't want the exact set of viable next tokens because the
  //  input might just be missing a token--you might consume the
  //  rest of the input looking for one of the missing tokens.
  //
  //  Consider grammar:
  //
  //  a : '[' b ']'
  //    | '(' b ')'
  //    ;
  //  b : c '^' INT ;
  //  c : ID
  //    | INT
  //    ;
  //
  //  At each rule invocation, the set of tokens that could follow
  //  that rule is pushed on a stack.  Here are the various
  //  context-sensitive follow sets:
  //
  //  FOLLOW(b1_in_a) = FIRST(']') = ']'
  //  FOLLOW(b2_in_a) = FIRST(')') = ')'
  //  FOLLOW(c_in_b) = FIRST('^') = '^'
  //
  //  Upon erroneous input "[]", the call chain is
  //
  //  a -> b -> c
  //
  //  and, hence, the follow context stack is:
  //
  //  depth     follow set       start of rule execution
  //    0         <EOF>                    a (from main())
  //    1          ']'                     b
  //    2          '^'                     c
  //
  //  Notice that ')' is not included, because b would have to have
  //  been called from a different context in rule a for ')' to be
  //  included.
  //
  //  For error recovery, we cannot consider FOLLOW(c)
  //  (context-sensitive or otherwise).  We need the combined set of
  //  all context-sensitive FOLLOW sets--the set of all tokens that
  //  could follow any reference in the call chain.  We need to
  //  resync to one of those tokens.  Note that FOLLOW(c)='^' and if
  //  we resync'd to that token, we'd consume until EOF.  We need to
  //  sync to context-sensitive FOLLOWs for a, b, and c: {']','^'}.
  //  In this case, for input "[]", LA(1) is ']' and in the set, so we would
  //  not consume anything. After printing an error, rule c would
  //  return normally.  Rule b would not find the required '^' though.
  //  At this point, it gets a mismatched token error and throws an
  //  exception (since LA(1) is not in the viable following token
  //  set).  The rule exception handler tries to recover, but finds
  //  the same recovery set and doesn't consume anything.  Rule b
  //  exits normally returning to rule a.  Now it finds the ']' (and
  //  with the successful match exits errorRecovery mode).
  //
  //  So, you can see that the parser walks up the call chain looking
  //  for the token that was a member of the recovery set.
  //
  //  Errors are not generated in errorRecovery mode.
  //
  //  antlr4dart's error recovery mechanism is based upon original ideas:
  //
  //  "Algorithms + Data Structures = Programs" by Niklaus Wirth
  //
  //  and
  //
  //  "A note on error recovery in recursive descent parsers":
  //  http://portal.acm.org/citation.cfm?id=947902.947905
  //
  //  Later, Josef Grosch had some good ideas:
  //
  //  "Efficient and Comfortable Error Recovery in Recursive Descent Parsers":
  //  ftp://www.cocolab.com/products/cocktail/doca4.ps/ell.ps.zip
  //
  //  Like Grosch I implement context-sensitive FOLLOW sets that are combined
  //  at run-time upon error to avoid overhead during parsing.
  IntervalSet _getErrorRecoverySet(Parser recognizer) {
    Atn atn = recognizer.interpreter.atn;
    RuleContext ctx = recognizer.context;
    IntervalSet recoverSet = new IntervalSet();
    while ( ctx!=null && ctx.invokingState>=0 ) {
      // compute what follows who invoked us
      AtnState invokingState = atn.states[ctx.invokingState];
      RuleTransition rt = invokingState.getTransition(0);
      IntervalSet follow = atn.nextTokensInSameRule(rt.followState);
      recoverSet.addAll(follow);
      ctx = ctx.parent;
    }
    recoverSet.remove(Token.EPSILON);
    return recoverSet;
  }

  // Consume tokens until one matches the given token set.
  void _consumeUntil(Parser recognizer, IntervalSet set) {
    int ttype = recognizer.inputSource.lookAhead(1);
    while (ttype != Token.EOF && !set.contains(ttype) ) {
      recognizer.consume();
      ttype = recognizer.inputSource.lookAhead(1);
    }
  }
}
