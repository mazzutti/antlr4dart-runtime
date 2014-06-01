part of antlr4dart;

/// Implements the `channel` lexer action by calling
/// [Lexer.channel]`=` with the assigned channel.
class LexerChannelAction implements LexerAction {

  /// The channel to use for the [Token] created by the lexer.
  final int channel;

  /// Constructs a new [channel] action with the specified channel value.
  /// [channel] is the channel value to pass to [Lexer.channel]`=`.
  LexerChannelAction(this.channel);

  /// Returns [LexerActionType.CHANNEL].
  LexerActionType get actionType => LexerActionType.CHANNEL;

  /// Always returns `false`.
  bool get isPositionDependent=> false;

  /// This action is implemented by calling [Lexer.channel]`=` with the
  /// value provided by [channel].
  void execute(Lexer lexer) {
    lexer.channel = channel;
  }

  int get hashCode {
    int hash = MurmurHash.initialize();
    hash = MurmurHash.update(hash, actionType.ordinal);
    hash = MurmurHash.update(hash, channel);
    return MurmurHash.finish(hash, 2);
  }

  bool operator ==(Object other) {
    if (other is LexerChannelAction) {
      return channel == other.channel;
    }
    return false;
  }

  String toString() => "channel($channel)";
}
