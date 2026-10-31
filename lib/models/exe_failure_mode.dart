enum ExeFailureMode {
  abort,
  continue_,
  ask;

  static const List<String> literalValues = ['abort', 'continue', 'ask'];

  static ExeFailureMode fromOption(dynamic option) {
    if (option == null) return ExeFailureMode.continue_;
    if (option is! String) {
      throw ArgumentError('Invalid on_failure: $option');
    }
    switch (option) {
      case 'abort':
        return ExeFailureMode.abort;
      case 'continue':
        return ExeFailureMode.continue_;
      case 'ask':
        return ExeFailureMode.ask;
      default:
        throw ArgumentError('Invalid on_failure: $option');
    }
  }

  String get yamlValue {
    switch (this) {
      case ExeFailureMode.abort:
        return 'abort';
      case ExeFailureMode.continue_:
        return 'continue';
      case ExeFailureMode.ask:
        return 'ask';
    }
  }
}
