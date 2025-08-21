import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // 키 상수들
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _loginTimeKey = 'login_time';
  static const String _pushServerUrlKey = 'push_server_url';

  /// Access Token 저장
  static Future<void> saveAccessToken(String token) async {
    try {
      await _storage.write(key: _accessTokenKey, value: token);
      debugPrint('Access token saved successfully');
    } catch (e) {
      debugPrint('Error saving access token: $e');
    }
  }

  /// Access Token 조회
  static Future<String?> getAccessToken() async {
    try {
      final token = await _storage.read(key: _accessTokenKey);
      debugPrint('Access token retrieved: ${token != null ? '[EXISTS]' : '[NULL]'}');
      return token;
    } catch (e) {
      debugPrint('Error getting access token: $e');
      return null;
    }
  }

  /// Refresh Token 저장
  static Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
      debugPrint('Refresh token saved successfully');
    } catch (e) {
      debugPrint('Error saving refresh token: $e');
    }
  }

  /// Refresh Token 조회
  static Future<String?> getRefreshToken() async {
    try {
      final token = await _storage.read(key: _refreshTokenKey);
      debugPrint('Refresh token retrieved: ${token != null ? '[EXISTS]' : '[NULL]'}');
      return token;
    } catch (e) {
      debugPrint('Error getting refresh token: $e');
      return null;
    }
  }

  /// 사용자 ID 저장
  static Future<void> saveUserId(String userId) async {
    try {
      await _storage.write(key: _userIdKey, value: userId);
      debugPrint('User ID saved successfully');
    } catch (e) {
      debugPrint('Error saving user ID: $e');
    }
  }

  /// 사용자 ID 조회
  static Future<String?> getUserId() async {
    try {
      final userId = await _storage.read(key: _userIdKey);
      debugPrint('User ID retrieved: ${userId ?? '[NULL]'}');
      return userId;
    } catch (e) {
      debugPrint('Error getting user ID: $e');
      return null;
    }
  }

  /// 로그인 시간 저장
  static Future<void> saveLoginTime() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      await _storage.write(key: _loginTimeKey, value: timestamp);
      debugPrint('Login time saved successfully');
    } catch (e) {
      debugPrint('Error saving login time: $e');
    }
  }

  /// 로그인 시간 조회
  static Future<DateTime?> getLoginTime() async {
    try {
      final timestampStr = await _storage.read(key: _loginTimeKey);
      if (timestampStr != null) {
        final timestamp = int.tryParse(timestampStr);
        if (timestamp != null) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting login time: $e');
      return null;
    }
  }

  /// 모든 인증 데이터 저장
  static Future<void> saveAuthData({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
      saveUserId(userId),
      saveLoginTime(),
    ]);
  }

  /// 모든 인증 데이터 삭제 (로그아웃)
  static Future<void> clearAuthData() async {
    try {
      await Future.wait([
        _storage.delete(key: _accessTokenKey),
        _storage.delete(key: _refreshTokenKey),
        _storage.delete(key: _userIdKey),
        _storage.delete(key: _loginTimeKey),
      ]);
      debugPrint('All auth data cleared successfully');
    } catch (e) {
      debugPrint('Error clearing auth data: $e');
    }
  }

  /// 저장된 인증 데이터 존재 여부 확인
  static Future<bool> hasAuthData() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    return accessToken != null && refreshToken != null;
  }

  /// 모든 데이터 조회 (디버깅용)
  static Future<Map<String, String?>> getAllAuthData() async {
    return {
      'access_token': await getAccessToken(),
      'refresh_token': await getRefreshToken(),
      'user_id': await getUserId(),
      'login_time': (await getLoginTime())?.toString(),
      'push_server_url': await getPushServerUrl(),
    };
  }

  /// 푸시 서버 URL 저장
  static Future<void> savePushServerUrl(String url) async {
    try {
      await _storage.write(key: _pushServerUrlKey, value: url);
      debugPrint('Push server URL saved successfully');
    } catch (e) {
      debugPrint('Error saving push server URL: $e');
    }
  }

  /// 푸시 서버 URL 조회
  static Future<String?> getPushServerUrl() async {
    try {
      final url = await _storage.read(key: _pushServerUrlKey);
      debugPrint('Push server URL retrieved: ${url != null ? '[EXISTS]' : '[NULL]'}');
      return url;
    } catch (e) {
      debugPrint('Error getting push server URL: $e');
      return null;
    }
  }

  /// 푸시 서버 URL 삭제
  static Future<void> deletePushServerUrl() async {
    try {
      await _storage.delete(key: _pushServerUrlKey);
      debugPrint('Push server URL deleted successfully');
    } catch (e) {
      debugPrint('Error deleting push server URL: $e');
    }
  }
}
