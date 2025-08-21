import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'main.dart'; // Global Navigator Key import
import 'deeplink_page.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  int _notificationId = 0;

  /// 알림 서비스 초기화
  Future<void> initialize() async {
    // 알림 권한 요청
    await _requestPermissions();

    // Android 초기화 설정
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 초기화 설정
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 통합 초기화 설정
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // 알림 플러그인 초기화
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Android 알림 채널 생성
    await _createNotificationChannel();
  }

  /// 알림 권한 요청
  Future<void> _requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  /// Android 알림 채널 생성
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'onecard_push',
      'OneCard Push Notifications',
      description: 'OneCard 애플리케이션의 푸시 알림',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// 알림 탭 이벤트 처리
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    
    if (response.payload != null && response.payload!.isNotEmpty) {
      // Deep link 처리
      PushNotificationService._handleDeepLink(response.payload!);
    }
  }

  /// Deep link 처리
  static void _handleDeepLink(String url) {
    debugPrint('Handling deep link: $url');
    
    try {
      final uri = Uri.parse(url);
      if (uri.scheme == 'onecard' && uri.host == 'auth') {
        // Global Navigator를 사용하여 Deep Link 페이지로 네비게이션
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => DeepLinkPage(
              url: url,
              params: uri.queryParameters,
            ),
          ),
        );
      } else {
        debugPrint('Unsupported deep link scheme: $url');
      }
    } catch (e) {
      debugPrint('Error processing deep link: $e');
    }
  }

  /// 푸시 알림 표시
  Future<void> showNotification({
    required String title,
    required String body,
    String? url,
  }) async {
    _notificationId++; // 각 알림에 고유 ID 부여 (대치 방지)

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'onecard_push',
      'OneCard Push Notifications',
      channelDescription: 'OneCard 애플리케이션의 푸시 알림',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      _notificationId,
      title,
      body,
      platformChannelSpecifics,
      payload: url, // Deep link URL을 payload로 전달
    );
  }

  /// 알림 권한 상태 확인
  Future<bool> hasPermission() async {
    return await Permission.notification.isGranted;
  }

  /// 모든 알림 취소
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// 특정 알림 취소
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}
