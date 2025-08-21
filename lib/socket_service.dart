import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'push_notification_service.dart';
import 'services/auth_service.dart';

enum SocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
  authenticationFailed,
}

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  SocketConnectionStatus _status = SocketConnectionStatus.disconnected;
  String? _currentServerUrl;
  String? _currentToken;
  final PushNotificationService _pushService = PushNotificationService();

  // 재시도 관련 변수
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 30; // 5분간 시도 (10초 * 30)
  static const Duration _reconnectInterval = Duration(seconds: 10);
  bool _isTokenRefreshing = false;

  // 네트워크 모니터링 관련 변수
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasConnectedBeforeNetworkLoss = false;
  Timer? _networkRecoveryTimer;
  
  // 연결 유지 관련 변수
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  int _heartbeatFailCount = 0;
  static const int _maxHeartbeatFails = 3;

  // 상태 변경 콜백
  Function(SocketConnectionStatus)? onStatusChanged;
  Function(String)? onError;
  Function(Map<String, dynamic>)? onPushReceived;

  SocketConnectionStatus get status => _status;
  bool get isConnected => _status == SocketConnectionStatus.connected;

  /// 푸시 서버에 연결
  Future<void> connect({
    required String serverUrl,
    required String token,
    bool overwrite = true,
  }) async {
    try {
      // 기존 연결이 있으면 끊기
      await disconnect();

      _currentServerUrl = serverUrl;
      _currentToken = token;

      _updateStatus(SocketConnectionStatus.connecting);

      // 네트워크 상태 모니터링 시작
      _startNetworkMonitoring();

      // Socket.IO 클라이언트 옵션 설정 (더 강력한 재연결 설정)
      final options = IO.OptionBuilder()
          .setTransports(['websocket']) // WebSocket만 사용
          .enableAutoConnect() // 자동 연결 활성화
          .enableReconnection() // 재연결 활성화
          .setReconnectionAttempts(5) // 내장 재연결 시도 횟수 증가
          .setReconnectionDelay(1000) // 초기 재연결 지연 시간
          .setReconnectionDelayMax(5000) // 최대 재연결 지연 시간
          .setTimeout(20000) // 연결 타임아웃 20초
          .setExtraHeaders({
            'Authorization': 'Bearer $token', // JWT 토큰을 헤더에 추가
          })
          .setQuery({
            'overwrite': overwrite.toString(), // 기존 연결 덮어쓰기 여부
          })
          .build();

      // Socket 생성 및 연결
      _socket = IO.io(serverUrl, options);

      // 이벤트 리스너 등록
      _setupEventListeners();

      // 연결 시작
      _socket!.connect();

    } catch (e) {
      debugPrint('Socket connection error: $e');
      _updateStatus(SocketConnectionStatus.error);
      onError?.call('연결 중 오류가 발생했습니다: $e');
    }
  }

  /// 이벤트 리스너 설정
  void _setupEventListeners() {
    if (_socket == null) return;

        // 연결 성공
    _socket!.on('connect', (data) {
      debugPrint('Socket connected: ${_socket!.id}');
      _updateStatus(SocketConnectionStatus.connected);
      
      // 연결 성공 시 재시도 카운터 리셋
      _reconnectAttempts = 0;
      _heartbeatFailCount = 0;
      
      // Heartbeat 시작
      _startHeartbeat();
    });

    // 연결 끊김
    _socket!.on('disconnect', (data) {
      debugPrint('Socket disconnected: $data');
      _updateStatus(SocketConnectionStatus.disconnected);
      
      // 연결이 끊어지면 현재 상태 기록
      _wasConnectedBeforeNetworkLoss = true;
      
      // Heartbeat 중지
      _stopHeartbeat();
      
      // 자동 재연결 시도 (네트워크 문제가 아닌 경우)
      if (data != 'io client disconnect') {
        _startReconnectTimer();
      }
    });

    // 연결 오류
    _socket!.on('connect_error', (data) {
      debugPrint('Socket connection error: $data');
      _updateStatus(SocketConnectionStatus.error);
      
      if (data.toString().contains('Authentication error') || 
          data.toString().contains('Unauthorized') ||
          data.toString().contains('401')) {
        debugPrint('Authentication failed, attempting token refresh...');
        _handleAuthenticationError();
      } else {
        // 네트워크 오류인 경우 재연결 시도
        if (_currentServerUrl != null && _currentToken != null) {
          _startReconnectTimer();
        }
        onError?.call('서버 연결에 실패했습니다: $data');
      }
    });

    // 연결 성공 메시지
    _socket!.on('connected', (data) {
      debugPrint('Server connected message: $data');
    });

    // 연결 거부 메시지
    _socket!.on('connection_rejected', (data) {
      debugPrint('Connection rejected: $data');
      _updateStatus(SocketConnectionStatus.error);
      onError?.call('연결이 거부되었습니다: ${data['message']}');
    });

    // 푸시 알림 수신
    _socket!.on('push_notification', (data) {
      debugPrint('Push notification received: $data');
      _handlePushNotification(data);
    });

    // 재연결 시도
    _socket!.on('reconnect_attempt', (attempt) {
      debugPrint('Reconnection attempt: $attempt');
    });

    // 재연결 성공
    _socket!.on('reconnect', (data) {
      debugPrint('Socket reconnected');
      _updateStatus(SocketConnectionStatus.connected);
    });

    // 재연결 실패
    _socket!.on('reconnect_failed', (data) {
      debugPrint('Socket reconnection failed');
      _updateStatus(SocketConnectionStatus.error);
      onError?.call('서버 재연결에 실패했습니다.');
    });
  }

  /// 푸시 알림 처리
  void _handlePushNotification(dynamic data) {
    try {
      Map<String, dynamic> pushData = Map<String, dynamic>.from(data);
      
      // 새로운 데이터 형식에 맞게 파싱
      String title = pushData['title'] ?? '알림';
      String content = pushData['message'] ?? '';
      
      // Deep Link URL 생성
      String? deepLinkUrl;
      if (pushData['client_id'] != null) {
        final clientId = pushData['client_id'];
        final serviceName = pushData['service_name'] ?? '';
        final attemptId = pushData['attempt_id'] ?? '';
        final empNo = pushData['emp_no'] ?? '';
        final dataValue = pushData['data'] ?? '';
        
        deepLinkUrl = 'onecard://auth?client_id=$clientId&service_name=$serviceName&attempt_id=$attemptId&emp_no=$empNo&data=$dataValue';
        
        debugPrint('Generated deep link: $deepLinkUrl');
      }

      // 콜백 호출 (UI 업데이트용)
      onPushReceived?.call({
        'title': title,
        'content': content,
        'url': deepLinkUrl,
        ...pushData, // 원본 데이터도 포함
      });

      // 로컬 알림 표시
      _pushService.showNotification(
        title: title,
        body: content,
        url: deepLinkUrl,
      );

    } catch (e) {
      debugPrint('Error handling push notification: $e');
    }
  }

  /// 연결 상태 업데이트
  void _updateStatus(SocketConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      onStatusChanged?.call(_status);
    }
  }

  /// 서버 연결 끊기
  Future<void> disconnect() async {
    // 모든 타이머 정리
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _networkRecoveryTimer?.cancel();
    _networkRecoveryTimer = null;
    
    // 네트워크 모니터링 중지
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    
    _reconnectAttempts = 0;
    _heartbeatFailCount = 0;
    _wasConnectedBeforeNetworkLoss = false;
    
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _updateStatus(SocketConnectionStatus.disconnected);
  }

  /// 재연결 시도
  Future<void> reconnect() async {
    if (_currentServerUrl != null && _currentToken != null) {
      await connect(
        serverUrl: _currentServerUrl!,
        token: _currentToken!,
      );
    }
  }

  /// 연결 상태 텍스트 반환
  String getStatusText() {
    switch (_status) {
      case SocketConnectionStatus.disconnected:
        return '연결 끊김';
      case SocketConnectionStatus.connecting:
        return '연결 중...';
      case SocketConnectionStatus.connected:
        return '연결됨';
      case SocketConnectionStatus.error:
        return '연결 오류';
      case SocketConnectionStatus.authenticationFailed:
        return '인증 실패';
    }
  }

  /// 연결 상태 색상 반환
  Color getStatusColor() {
    switch (_status) {
      case SocketConnectionStatus.disconnected:
        return Colors.grey;
      case SocketConnectionStatus.connecting:
        return Colors.orange;
      case SocketConnectionStatus.connected:
        return Colors.green;
      case SocketConnectionStatus.error:
      case SocketConnectionStatus.authenticationFailed:
        return Colors.red;
    }
  }

  /// 네트워크 상태 모니터링 시작
  void _startNetworkMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _handleNetworkChange(results);
      },
    );
  }

  /// 네트워크 상태 변화 처리
  void _handleNetworkChange(List<ConnectivityResult> results) {
    final hasConnection = !results.contains(ConnectivityResult.none);
    
    debugPrint('Network connectivity changed: $results');
    
    if (hasConnection && _wasConnectedBeforeNetworkLoss && !isConnected) {
      debugPrint('Network recovered, attempting to reconnect...');
      _wasConnectedBeforeNetworkLoss = false;
      
      // 네트워크 복구 후 짧은 지연 후 재연결 시도
      _networkRecoveryTimer?.cancel();
      _networkRecoveryTimer = Timer(const Duration(seconds: 2), () {
        _attemptReconnect();
      });
    } else if (!hasConnection && isConnected) {
      debugPrint('Network lost, connection will be handled by disconnect event');
      _wasConnectedBeforeNetworkLoss = true;
    }
  }

  /// Heartbeat 시작
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      _sendHeartbeat();
    });
  }

  /// Heartbeat 중지
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Heartbeat 신호 전송
  void _sendHeartbeat() {
    if (_socket?.connected == true) {
      _socket!.emit('ping', {'timestamp': DateTime.now().millisecondsSinceEpoch});
      
      // Pong 응답 대기
      _socket!.once('pong', (data) {
        _heartbeatFailCount = 0;
        debugPrint('Heartbeat pong received');
      });
      
      // Pong 응답이 없으면 실패 카운트 증가
      Timer(const Duration(seconds: 10), () {
        _heartbeatFailCount++;
        debugPrint('Heartbeat fail count: $_heartbeatFailCount');
        
        if (_heartbeatFailCount >= _maxHeartbeatFails) {
          debugPrint('Too many heartbeat failures, forcing reconnection');
          _heartbeatFailCount = 0;
          _wasConnectedBeforeNetworkLoss = true;
          _socket?.disconnect();
        }
      });
    }
  }
  /// 재연결 타이머 시작 (개선된 로직)
  void _startReconnectTimer() {
    // 이미 재연결 중이거나 최대 시도 횟수를 초과한 경우 중단
    if (_reconnectTimer?.isActive == true || _reconnectAttempts >= _maxReconnectAttempts) {
      if (_reconnectAttempts >= _maxReconnectAttempts) {
        debugPrint('Max reconnection attempts reached. Will retry when network changes.');
        onError?.call('서버 연결에 계속 실패하고 있습니다. 네트워크 상태를 확인해주세요.');
        // 최대 시도 횟수 도달 시에도 네트워크 모니터링은 유지
        _wasConnectedBeforeNetworkLoss = true;
      }
      return;
    }

    _reconnectAttempts++;
    
    // 지수 백오프: 시도 횟수에 따라 대기 시간 증가
    final delaySeconds = (_reconnectInterval.inSeconds * (_reconnectAttempts / 5).ceil()).clamp(5, 60);
    final delay = Duration(seconds: delaySeconds);
    
    debugPrint('Starting reconnect timer (attempt $_reconnectAttempts/$_maxReconnectAttempts) - delay: ${delay.inSeconds}s');
    
    _reconnectTimer = Timer(delay, () async {
      if (_currentServerUrl != null && _currentToken != null) {
        debugPrint('Attempting to reconnect...');
        await _attemptReconnect();
      }
    });
  }

  /// 재연결 시도 (개선된 로직)
  Future<void> _attemptReconnect() async {
    try {
      // 현재 네트워크 상태 확인
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        debugPrint('No network connectivity, skipping reconnection attempt');
        _wasConnectedBeforeNetworkLoss = true;
        return;
      }

      await connect(
        serverUrl: _currentServerUrl!,
        token: _currentToken!,
        overwrite: false,
      );
      
      // 연결 성공 시 재시도 카운터 리셋
      _reconnectAttempts = 0;
      _wasConnectedBeforeNetworkLoss = false;
      debugPrint('Reconnection successful');
    } catch (e) {
      debugPrint('Reconnection failed: $e');
      
      // 토큰 만료로 인한 실패인 경우 토큰 새로고침 시도
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        await _handleAuthenticationError();
      } else {
        // 일반적인 연결 실패 - 다시 타이머 시작
        if (_reconnectAttempts < _maxReconnectAttempts) {
          _startReconnectTimer();
        }
      }
    }
  }

  /// 인증 오류 처리 (토큰 재발급 시도)
  Future<void> _handleAuthenticationError() async {
    if (_isTokenRefreshing) {
      debugPrint('Token refresh already in progress');
      return;
    }

    _isTokenRefreshing = true;
    _updateStatus(SocketConnectionStatus.authenticationFailed);

    try {
      debugPrint('Attempting to refresh token...');
      final tokenData = await AuthService.refreshToken();
      
      if (tokenData != null && tokenData.containsKey('access_token')) {
        final newToken = tokenData['access_token'];
        _currentToken = newToken;
        
        debugPrint('Token refreshed successfully, reconnecting...');
        
        // 새 토큰으로 재연결 시도
        await connect(
          serverUrl: _currentServerUrl!,
          token: newToken,
          overwrite: false,
        );
        
        debugPrint('Reconnection with new token successful');
      } else {
        debugPrint('Token refresh failed');
        _updateStatus(SocketConnectionStatus.authenticationFailed);
        onError?.call('인증에 실패했습니다. 다시 로그인해주세요.');
      }
    } catch (e) {
      debugPrint('Error during token refresh: $e');
      _updateStatus(SocketConnectionStatus.authenticationFailed);
      onError?.call('토큰 갱신에 실패했습니다. 다시 로그인해주세요.');
    } finally {
      _isTokenRefreshing = false;
    }
  }
}
