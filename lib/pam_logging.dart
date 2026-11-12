/// The SDK feature that produced a log entry.
enum PamLogCategory {
  general('General'),
  tracking('Tracking'),
  identity('Identity'),
  consent('Consent'),
  push('Push'),
  attention('Attention'),
  storage('Storage');

  const PamLogCategory(this.label);
  final String label;
}

/// Native severity used by Logcat and Apple's unified logging system.
enum PamLogLevel {
  debug('DEBUG'),
  info('INFO'),
  warning('WARN'),
  error('ERROR');

  const PamLogLevel(this.label);
  final String label;
}
