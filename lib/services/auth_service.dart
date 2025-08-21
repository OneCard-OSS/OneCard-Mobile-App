import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../socket_service.dart';
import 'secure_storage_service.dart';

class AuthService {
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// 로그인 시작 API 호출
  static Future<Map<String, dynamic>?> initiateLogin(String empNo) async {
    try {
      final url = AppConfig.getApiUrl(AppConfig.loginInitiateEndpoint);
      debugPrint('Initiating login for employee: $empNo');
      debugPrint('Request URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'emp_no': empNo,
        }),
      ).timeout(_requestTimeout);

      debugPrint('Login initiate response status: ${response.statusCode}');
      debugPrint('Login initiate response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        debugPrint('Login initiate failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error during login initiate: $e');
      return null;
    }
  }

  /// 로그인 검증 API 호출
  static Future<Map<String, dynamic>?> verifyLogin({
    required String attemptId,
    required String encryptedData,
  }) async {
    try {
      final url = AppConfig.getApiUrl(AppConfig.loginVerifyEndpoint);
      debugPrint('Verifying login with attempt_id: $attemptId');
      debugPrint('Request URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'attempt_id': attemptId,
          'encrypted_data':encryptedData
        }),
      ).timeout(_requestTimeout);

      debugPrint('Login verify response status: ${response.statusCode}');
      debugPrint('Login verify response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // 토큰이 포함된 경우 저장
        if (data.containsKey('access_token') && data.containsKey('refresh_token')) {
          await SecureStorageService.saveAuthData(
            accessToken: data['access_token'],
            refreshToken: data['refresh_token'],
            userId: attemptId, // 또는 실제 사용자 ID
          );
          
          // 로그인 성공 후 즉시 푸시 서버에 연결
          _initiatePushConnection(data['access_token']);
        }
        
        return data;
      } else {
        debugPrint('Login verify failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error during login verify: $e');
      return null;
    }
  }

  /// 푸시 서버 연결 시작
  static void _initiatePushConnection(String accessToken) async {
    try {
      debugPrint('Initiating push server connection after login...');
      
      // 푸시 서버 URL 가져오기
      final pushServerUrl = await SecureStorageService.getPushServerUrl();
      final serverUrl = pushServerUrl ?? AppConfig.pushServerUrl;
      
      // 서버 URL이 저장되지 않았으면 저장
      if (pushServerUrl == null) {
        await SecureStorageService.savePushServerUrl(serverUrl);
      }
      
      // 소켓 서비스 인스턴스를 통해 연결
      final socketService = SocketService();
      await socketService.connect(
        serverUrl: serverUrl,
        token: accessToken,
        overwrite: true,
      );
      
      debugPrint('Push server connection initiated successfully');
    } catch (e) {
      debugPrint('Failed to initiate push connection: $e');
    }
  }

  /// 토큰 갱신 API 호출
  static Future<Map<String, dynamic>?> refreshToken() async {
    try {
      final refreshToken = await SecureStorageService.getRefreshToken();
      if (refreshToken == null) {
        debugPrint('No refresh token available');
        return null;
      }

      final url = AppConfig.getApiUrl(AppConfig.tokenRefreshEndpoint);
      debugPrint('Refreshing token');
      debugPrint('Request URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refresh_token': refreshToken,
        }),
      ).timeout(_requestTimeout);

      debugPrint('Token refresh response status: ${response.statusCode}');
      debugPrint('Token refresh response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // 새로운 토큰 저장
        if (data.containsKey('access_token') && data.containsKey('refresh_token')) {
          final userId = await SecureStorageService.getUserId();
          await SecureStorageService.saveAuthData(
            accessToken: data['access_token'],
            refreshToken: data['refresh_token'],
            userId: userId ?? 'unknown',
          );
        }
        
        return data;
      } else {
        debugPrint('Token refresh failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error during token refresh: $e');
      return null;
    }
  }

  /// 로그아웃 API 호출
  static Future<bool> logout() async {
    try {
      final accessToken = await SecureStorageService.getAccessToken();
      if (accessToken == null) {
        debugPrint('No access token available for logout');
        await SecureStorageService.clearAuthData();
        return true;
      }

      final url = AppConfig.getApiUrl(AppConfig.logoutEndpoint);
      debugPrint('Logging out');
      debugPrint('Request URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(_requestTimeout);

      debugPrint('Logout response status: ${response.statusCode}');
      debugPrint('Logout response body: ${response.body}');

      // 성공 여부와 관계없이 로컬 토큰은 삭제
      await SecureStorageService.clearAuthData();

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error during logout: $e');
      // 에러가 발생해도 로컬 토큰은 삭제
      await SecureStorageService.clearAuthData();
      return false;
    }
  }

  /// 자동 로그인 시도
  static Future<bool> attemptAutoLogin() async {
    try {
      debugPrint('Attempting auto login...');
      
      // 저장된 토큰 확인
      final hasAuth = await SecureStorageService.hasAuthData();
      if (!hasAuth) {
        debugPrint('No auth data available for auto login');
        return false;
      }

      // Access token으로 먼저 시도 (실제로는 유효성 검증 API가 필요)
      final accessToken = await SecureStorageService.getAccessToken();
      if (accessToken != null) {
        // TODO: Access token 유효성 검증 API 호출
        // 현재는 토큰이 존재하면 유효하다고 가정
        debugPrint('Auto login with access token successful');
        return true;
      }

      // Access token이 없거나 유효하지 않으면 refresh token으로 시도
      debugPrint('Access token invalid, trying refresh token...');
      final refreshResult = await refreshToken();
      
      if (refreshResult != null && refreshResult.containsKey('access_token')) {
        debugPrint('Auto login with refresh token successful');
        return true;
      }

      debugPrint('Auto login failed - refresh token also invalid');
      await SecureStorageService.clearAuthData();
      return false;

    } catch (e) {
      debugPrint('Error during auto login: $e');
      return false;
    }
  }

  /// 현재 로그인 상태 확인
  static Future<bool> isLoggedIn() async {
    final accessToken = await SecureStorageService.getAccessToken();
    return accessToken != null;
  }

  /// 현재 사용자 ID 가져오기
  static Future<String?> getCurrentUserId() async {
    return await SecureStorageService.getUserId();
  }

  /// 카드 응답 전송 API 호출
  static Future<Map<String, dynamic>?> sendCardResponse({
    required String cardData,
    required String attemptId,
    required String clientId,
  }) async {
    try {
      const url = 'http://203.237.81.247:9414/api/v1/card-response';
      debugPrint('Sending card response to: $url');
      debugPrint('Card data length: ${cardData.length}');
      debugPrint('Attempt ID: $attemptId');
      debugPrint('Client ID: $clientId');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'card_data': cardData,
          'attempt_id': attemptId,
          'client_id': clientId,
        }),
      ).timeout(_requestTimeout);

      debugPrint('Card response status: ${response.statusCode}');
      debugPrint('Card response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        debugPrint('Card response failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error during card response: $e');
      return null;
    }
  }
}
