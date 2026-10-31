import 'package:flutter/foundation.dart';

const String _apiOverride = String.fromEnvironment('API_BASE_URL');
const String _portalOverride = String.fromEnvironment('TEACHER_PORTAL_URL');

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

String get apiBaseUrl {
  if (_apiOverride.isNotEmpty) return _apiOverride;
  return _isAndroid ? 'http://10.0.2.2:5000' : 'http://localhost:5000';
}

String get teacherPortalUrl {
  if (_portalOverride.isNotEmpty) return _portalOverride;
  return _isAndroid ? 'http://10.0.2.2:5173' : 'http://localhost:5173';
}
