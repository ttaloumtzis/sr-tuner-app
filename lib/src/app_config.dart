class AppConfig {
  static const appName = 'sr-tuner';
  static const backendHost = '127.0.0.1';
  static const backendPort = 8765;
  static const healthPath = '/health';

  static Uri apiUri(String path) {
    return Uri.http('$backendHost:$backendPort', path);
  }
}
