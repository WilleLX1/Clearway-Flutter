import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static const _configuredBase = String.fromEnvironment(
    'CLEARWAY_API_BASE',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_configuredBase.isNotEmpty) {
      return _configuredBase.replaceFirst(RegExp(r'/$'), '');
    }

    // The Android emulator reaches the development machine through 10.0.2.2.
    // Physical devices should pass --dart-define=CLEARWAY_API_BASE=http://...
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }
}
