import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // 싱글톤 패턴
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  // 환경 변수 로드
  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
  }

  // API 서버 설정
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://203.237.81.63:9415';
  static String get loginInitiateEndpoint => dotenv.env['LOGIN_INITIATE_ENDPOINT'] ?? '/app/api/initiate';
  static String get loginVerifyEndpoint => dotenv.env['LOGIN_VERIFY_ENDPOINT'] ?? '/app/api/verify';
  static String get tokenRefreshEndpoint => dotenv.env['TOKEN_REFRESH_ENDPOINT'] ?? '/app/api/token';
  static String get logoutEndpoint => dotenv.env['LOGOUT_ENDPOINT'] ?? '/app/api/logout';

  // 푸시 서버 설정
  static String get pushServerUrl => dotenv.env['PUSH_SERVER_URL'] ?? 'http://localhost:3000';
  static String get jwtSecret => dotenv.env['JWT_SECRET'] ?? 'onecard_secret_key_for_testing_12345';

  // 백그라운드 서비스 설정
  static int get backgroundServiceIntervalMinutes => 
      int.tryParse(dotenv.env['BACKGROUND_SERVICE_INTERVAL_MINUTES'] ?? '15') ?? 15;
  static int get autoReconnectAttempts => 
      int.tryParse(dotenv.env['AUTO_RECONNECT_ATTEMPTS'] ?? '3') ?? 3;

  // 개발/디버그 설정
  static bool get debugMode => dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';
  static String get logLevel => dotenv.env['LOG_LEVEL'] ?? 'debug';

  // 전체 API URL 생성 헬퍼
  static String getApiUrl(String endpoint) => '$apiBaseUrl$endpoint';
}
