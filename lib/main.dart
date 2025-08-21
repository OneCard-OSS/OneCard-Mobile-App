import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'push_notification_service.dart';
import 'socket_service.dart';
import 'deeplink_page.dart';
import 'config/app_config.dart';
import 'services/background_service.dart';
import 'services/auth_service.dart';
import 'services/secure_storage_service.dart';
import 'screens/login_page.dart';
import 'screens/push_history_page.dart';
import 'screens/change_pin_page.dart';
import 'screens/card_info_page.dart';

// Global Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 환경 변수 로드
  await AppConfig.load();
  
  // 푸시 알림 서비스 초기화
  await PushNotificationService().initialize();
  
  // 백그라운드 서비스 초기화
  await BackgroundService.initialize();
  
  // 자동 푸시 서버 연결 시작
  _initializeAutoPushConnection();
  
  runApp(const MyApp());
}

/// 자동 푸시 서버 연결 초기화
void _initializeAutoPushConnection() async {
  try {
    // 저장된 인증 정보 확인
    final accessToken = await SecureStorageService.getAccessToken();
    final serverUrl = await SecureStorageService.getPushServerUrl();
    
    if (accessToken != null && serverUrl != null) {
      debugPrint('Auto-connecting to push server...');
      
      // 백그라운드에서 푸시 서버 연결
      final socketService = SocketService();
      await socketService.connect(
        serverUrl: serverUrl,
        token: accessToken,
      );
      
      debugPrint('Auto push connection initiated');
    } else {
      debugPrint('No stored credentials for auto push connection');
    }
  } catch (e) {
    debugPrint('Auto push connection failed: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel('onecard_client/deeplink');
  
  @override
  void initState() {
    super.initState();
    _handleInitialLink();
    _handleIncomingLinks();
  }

  // 앱이 종료된 상태에서 Deep Link로 시작된 경우 처리
  void _handleInitialLink() async {
    try {
      final String? initialLink = await platform.invokeMethod('getInitialLink');
      if (initialLink != null) {
        _processDeepLink(initialLink);
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get initial link: '${e.message}'.");
    }
  }

  // 앱이 실행 중일 때 Deep Link 처리
  void _handleIncomingLinks() {
    platform.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onNewLink') {
        final String link = call.arguments;
        _processDeepLink(link);
      }
    });
  }

  // Deep Link 처리
  void _processDeepLink(String link) {
    debugPrint('Processing deep link: $link');
    
    final uri = Uri.parse(link);
    if (uri.scheme == 'onecard' && uri.host == 'auth') {
      // Deep Link 페이지로 네비게이션
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DeepLinkPage(
            url: link,
            params: uri.queryParameters,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneCard 통합인증 서비스',
      navigatorKey: navigatorKey, // Global Navigator Key 설정
      debugShowCheckedModeBanner: false, // DEBUG 표식 제거
      theme: ThemeData(
        // White/Black 색상 스키마 설정
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.grey,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: Colors.black,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
          ),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/main': (context) => const PushTestPage(),
        '/login': (context) => const LoginPage(),
        '/deeplink': (context) => const DeepLinkPage(),
      },
    );
  }
}

/// 인증 상태에 따라 화면을 결정하는 Wrapper
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // 로그인 상태 확인
      final isLoggedIn = await AuthService.isLoggedIn();
      
      if (isLoggedIn) {
        // 자동 로그인 시도
        final autoLoginSuccess = await AuthService.attemptAutoLogin();
        
        if (autoLoginSuccess) {
          // 백그라운드 서비스 시작
          await BackgroundService.startPushNotificationService();
          
          // 푸시 서버 자동 연결
          await _establishPushConnection();
          
          setState(() {
            _isLoggedIn = true;
          });
        } else {
          setState(() {
            _isLoggedIn = false;
          });
        }
      } else {
        setState(() {
          _isLoggedIn = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
      setState(() {
        _isLoggedIn = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 푸시 서버 연결 설정 (강화된 버전)
  Future<void> _establishPushConnection() async {
    try {
      final accessToken = await SecureStorageService.getAccessToken();
      final pushServerUrl = await SecureStorageService.getPushServerUrl();
      
      // 기본 서버 URL이 없으면 환경 설정에서 가져오기
      String serverUrl = pushServerUrl ?? AppConfig.pushServerUrl;
      
      if (accessToken != null) {
        debugPrint('Establishing enhanced push connection to: $serverUrl');
        
        final socketService = SocketService();
        
        // 연결 상태 모니터링 콜백 설정
        socketService.onStatusChanged = (status) {
          debugPrint('Push connection status changed: $status');
        };
        
        socketService.onError = (error) {
          debugPrint('Push connection error: $error');
        };
        
        // 강화된 연결 설정으로 연결 (재연결 및 네트워크 모니터링 포함)
        await socketService.connect(
          serverUrl: serverUrl,
          token: accessToken,
          overwrite: true,
        );
        
        // 서버 URL이 저장되지 않았으면 저장
        if (pushServerUrl == null) {
          await SecureStorageService.savePushServerUrl(serverUrl);
        }
        
        debugPrint('Enhanced push connection established with auto-reconnection');
      } else {
        debugPrint('No access token available for push connection');
      }
    } catch (e) {
      debugPrint('Error establishing enhanced push connection: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.credit_card,
                size: 80,
                color: Colors.black,
              ),
              SizedBox(height: 24),
              Text(
                'OneCard',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(color: Colors.black),
              SizedBox(height: 16),
              Text('인증 상태 확인 중...', style: TextStyle(color: Colors.black)),
            ],
          ),
        ),
      );
    }

    return _isLoggedIn ? const PushTestPage() : const LoginPage();
  }
}

class PushTestPage extends StatefulWidget {
  const PushTestPage({super.key});

  @override
  State<PushTestPage> createState() => _PushTestPageState();
}

class _PushTestPageState extends State<PushTestPage> {
  final SocketService _socketService = SocketService();
  
  List<Map<String, dynamic>> _receivedMessages = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Socket 서비스 이벤트 리스너 설정
    // _socketService.onPushReceived = (data) {
    //   setState(() {
    //     _receivedMessages.insert(0, {
    //       ...data,
    //       'timestamp': DateTime.now(),
    //     });
    //   });
    //   _showSnackBar('푸시 알림이 도착했습니다: ${data['title']}');
    // };

    setState(() {});
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Deep Link 클릭 처리
  void _handleDeepLinkTap(String deepLinkUrl) {
    try {
      debugPrint('Deep link tapped: $deepLinkUrl');
      
      final uri = Uri.parse(deepLinkUrl);
      if (uri.scheme == 'onecard' && uri.host == 'auth') {
        // Deep Link 페이지로 네비게이션
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DeepLinkPage(
              url: deepLinkUrl,
              params: uri.queryParameters,
            ),
          ),
        );
      } else {
        _showSnackBar('지원하지 않는 링크 형식입니다.', isError: true);
      }
    } catch (e) {
      debugPrint('Error handling deep link tap: $e');
      _showSnackBar('링크 처리 중 오류가 발생했습니다.', isError: true);
    }
  }

  Future<void> _logout() async {
    try {
      // 백그라운드 서비스 중지
      await BackgroundService.stopPushNotificationService();
      
      // 소켓 연결 끊기
      await _socketService.disconnect();
      
      // 로그아웃 API 호출 및 토큰 삭제
      await AuthService.logout();
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      debugPrint('Logout error: $e');
      _showSnackBar('로그아웃 중 오류가 발생했습니다.', isError: true);
    }
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OneCard 통합 인증 서비스'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          // 푸시 메시지 내역 버튼 (종 모양)
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PushHistoryPage(
                        messages: _receivedMessages,
                        onDeleteMessage: (index) {
                          setState(() {
                            _receivedMessages.removeAt(index);
                          });
                        },
                        onClearAll: () {
                          setState(() {
                            _receivedMessages.clear();
                          });
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications),
                tooltip: '푸시 알림 내역',
              ),
              if (_receivedMessages.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '${_receivedMessages.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 메인 기능 버튼들
            const Text(
              'OneCard 관리',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            
            // PIN 변경 버튼
            Card(
              elevation: 2,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ChangePinPage(),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security,
                        size: 32,
                        color: Colors.black,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PIN 변경',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '카드의 PIN 번호를 변경합니다',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 카드 정보 조회 버튼
            Card(
              elevation: 2,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CardInfoPage(),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.credit_card,
                        size: 32,
                        color: Colors.black,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '카드 정보 조회',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '카드의 상세 정보를 확인합니다',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // 최근 푸시 메시지 미리보기
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '최근 알림',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PushHistoryPage(
                          messages: _receivedMessages,
                          onDeleteMessage: (index) {
                            setState(() {
                              _receivedMessages.removeAt(index);
                            });
                          },
                          onClearAll: () {
                            setState(() {
                              _receivedMessages.clear();
                            });
                          },
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.black),
                  child: const Text('전체보기'),
                ),
              ],
            ),
            
            const SizedBox(height: 10),

            // 메시지 목록 (최대 3개만 표시)
            Expanded(
              child: _receivedMessages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 60,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '수신된 알림이 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _receivedMessages.length > 3 ? 3 : _receivedMessages.length,
                      itemBuilder: (context, index) {
                        final message = _receivedMessages[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.black,
                              child: Icon(Icons.notifications, color: Colors.white, size: 16),
                            ),
                            title: Text(
                              message['title'] ?? '제목 없음',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['content'] ?? '내용 없음',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${message['timestamp']?.toString().substring(0, 19) ?? ''}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            onTap: message['url'] != null 
                                ? () => _handleDeepLinkTap(message['url']) 
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
