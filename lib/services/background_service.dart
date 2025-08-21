import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import '../services/secure_storage_service.dart';
import '../socket_service.dart';
import '../config/app_config.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('Background task started: $task');
    
    try {
      switch (task) {
        case BackgroundService.pushNotificationTask:
          await BackgroundService._handlePushNotificationTask();
          break;
        default:
          debugPrint('Unknown background task: $task');
          return false;
      }
      
      debugPrint('Background task completed successfully: $task');
      return true;
    } catch (e) {
      debugPrint('Background task failed: $task, error: $e');
      return false;
    }
  });
}

class BackgroundService {
  static const String pushNotificationTask = 'push_notification_task';
  static const String uniqueTaskName = 'onecard_push_service';
  
  static bool _isInitialized = false;

  /// 백그라운드 서비스 초기화
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: AppConfig.debugMode,
      );
      _isInitialized = true;
      debugPrint('Background service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing background service: $e');
    }
  }

  /// 푸시 알림 백그라운드 서비스 시작
  static Future<void> startPushNotificationService() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // 기존 작업 취소
      await Workmanager().cancelByUniqueName(uniqueTaskName);

      // 주기적 작업 등록
      await Workmanager().registerPeriodicTask(
        uniqueTaskName,
        pushNotificationTask,
        frequency: Duration(minutes: AppConfig.backgroundServiceIntervalMinutes),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
        inputData: {
          'service_type': 'push_notification',
          'auto_start': true,
        },
      );

      debugPrint('Push notification background service started');
    } catch (e) {
      debugPrint('Error starting push notification service: $e');
    }
  }

  /// 백그라운드 서비스 중지
  static Future<void> stopPushNotificationService() async {
    try {
      await Workmanager().cancelByUniqueName(uniqueTaskName);
      debugPrint('Push notification background service stopped');
    } catch (e) {
      debugPrint('Error stopping push notification service: $e');
    }
  }

  /// 모든 백그라운드 작업 취소
  static Future<void> cancelAllTasks() async {
    try {
      await Workmanager().cancelAll();
      debugPrint('All background tasks cancelled');
    } catch (e) {
      debugPrint('Error cancelling background tasks: $e');
    }
  }

  /// 푸시 알림 백그라운드 작업 처리 (강화된 버전)
  static Future<void> _handlePushNotificationTask() async {
    debugPrint('Executing enhanced push notification background task');

    try {
      // 저장된 토큰 및 서버 URL 확인
      final accessToken = await SecureStorageService.getAccessToken();
      final pushServerUrl = await SecureStorageService.getPushServerUrl();
      
      if (accessToken == null) {
        debugPrint('No access token available for background service');
        return;
      }

      final serverUrl = pushServerUrl ?? AppConfig.pushServerUrl;
      
      // Socket 서비스 인스턴스 생성
      final socketService = SocketService();

      // 푸시 서버에 강화된 연결 시도 (자동 재연결 포함)
      if (!socketService.isConnected) {
        debugPrint('Attempting enhanced push server connection in background');
        
        await socketService.connect(
          serverUrl: serverUrl,
          token: accessToken,
          overwrite: false, // 기존 연결이 있으면 유지
        );

        // 연결 확인을 위한 대기
        await Future.delayed(const Duration(seconds: 3));

        if (socketService.isConnected) {
          debugPrint('Successfully connected to push server in background with auto-reconnection');
        } else {
          debugPrint('Push server connection will be handled by auto-reconnection logic');
        }
      } else {
        debugPrint('Push server already connected in background');
      }

    } catch (e) {
      debugPrint('Error in push notification background task: $e');
    }
  }

  /// 백그라운드 서비스 상태 확인
  static Future<bool> isServiceRunning() async {
    try {
      // WorkManager에서 실행 중인 작업 확인하는 방법이 제한적이므로
      // 대신 SharedPreferences나 다른 방법으로 상태를 관리할 수 있습니다.
      return true; // 임시로 true 반환
    } catch (e) {
      debugPrint('Error checking service status: $e');
      return false;
    }
  }

  /// 부팅 시 자동 시작을 위한 설정
  static Future<void> enableAutoStart() async {
    try {
      // Android에서는 BOOT_COMPLETED receiver를 통해 처리
      // 이는 AndroidManifest.xml 설정과 함께 작동합니다.
      await startPushNotificationService();
      debugPrint('Auto start enabled for background service');
    } catch (e) {
      debugPrint('Error enabling auto start: $e');
    }
  }

  /// 서비스 상태 정보 가져오기
  static Future<Map<String, dynamic>> getServiceStatus() async {
    try {
      final isRunning = await isServiceRunning();
      final hasToken = await SecureStorageService.hasAuthData();
      
      return {
        'is_running': isRunning,
        'has_auth_token': hasToken,
        'service_interval_minutes': AppConfig.backgroundServiceIntervalMinutes,
        'auto_reconnect_attempts': AppConfig.autoReconnectAttempts,
        'last_check': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting service status: $e');
      return {
        'is_running': false,
        'has_auth_token': false,
        'error': e.toString(),
      };
    }
  }
}
