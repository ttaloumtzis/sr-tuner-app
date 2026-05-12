class AppConfig {
  static const appName = 'sr-tuner';
  static const backendHost = '127.0.0.1';
  static const backendPort = 8765;
  static const healthPath = '/health';

  static Uri apiUri(String path) {
    final relative = Uri.parse(path.startsWith('/') ? path : '/$path');
    return Uri(
      scheme: 'http',
      host: backendHost,
      port: backendPort,
      path: relative.path,
      query: relative.hasQuery ? relative.query : null,
      fragment: relative.hasFragment ? relative.fragment : null,
    );
  }
}
