part of antlr4dart;

class AtnDeserializationOptions {
  
  static final AtnDeserializationOptions defaultOptions = () {
    var defaultOptions = new AtnDeserializationOptions();
    defaultOptions._readOnly = true;
    return defaultOptions;
  }();

  bool _readOnly;
  bool _verifyAtn;
  bool _generateRuleBypassTransitions;

  AtnDeserializationOptions() {
    _verifyAtn = true;
    _generateRuleBypassTransitions = false;
  }

  AtnDeserializationOptions.from(AtnDeserializationOptions options) {
    _verifyAtn = options.isVerifyAtn;
    _generateRuleBypassTransitions = options.isGenerateRuleBypassTransitions;
  }

  bool get isVerifyAtn => _verifyAtn;
  
  bool get isReadOnly => _readOnly;

  void set isVerifyAtn(bool verifyAtn) {
    _throwIfReadOnly();
    _verifyAtn = verifyAtn;
  }

  bool get isGenerateRuleBypassTransitions => _generateRuleBypassTransitions;

  void set isGenerateRuleBypassTransitions(bool generateRuleBypassTransitions) {
    _throwIfReadOnly();
    _generateRuleBypassTransitions = generateRuleBypassTransitions;
  }

  void _throwIfReadOnly() {
    if (_readOnly) {
      throw new StateError("The object is read only.");
    }
  }
}
