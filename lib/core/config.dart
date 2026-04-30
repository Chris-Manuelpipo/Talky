// lib/core/config.dart

class AppConfig {
  AppConfig._();

  //static const String _kDefaultHost = 'talky-signaling.onrender.com';
  static const String _kDefaultHost = '158.220.107.211';

  static String get signalingUrl {
    return String.fromEnvironment(
      'SIGNALING_URL',
      defaultValue: 'http://$_kDefaultHost',
    );
  }

  static String get apiUrl {
    return String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://$_kDefaultHost/api',
    );
  }

  static String get socketUrl {
    return String.fromEnvironment(
      'SOCKET_URL',
      defaultValue: 'http://$_kDefaultHost',
    );
  }

  static String get notifyUrl {
    return String.fromEnvironment(
      'NOTIFY_URL',
      defaultValue: 'http://$_kDefaultHost/api/notify',
    );
  }
}
