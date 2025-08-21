import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../NFCOperation.dart';
import '../services/auth_service.dart';

class DeepLinkPage extends StatefulWidget {
  final String? url;
  final Map<String, String>? params;

  const DeepLinkPage({
    super.key,
    this.url,
    this.params,
  });

  @override
  State<DeepLinkPage> createState() => _DeepLinkPageState();
}

class _DeepLinkPageState extends State<DeepLinkPage> {
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _errorMessage;
  
  String? get _serviceId => widget.params?['service_id'];
  String? get _attemptId => widget.params?['attempt_id'];
  String? get _clientId => widget.params?['client_id'];
  String? get _data => widget.params?['data'];

  @override
  void initState() {
    super.initState();
    _logDeepLinkInfo();
  }

  void _logDeepLinkInfo() {
    // URL과 파라미터 정보를 로그로 출력
    debugPrint('=== Deep Link Access Info ===');
    debugPrint('URL: ${widget.url ?? '없음'}');
    debugPrint('Access Time: ${DateTime.now()}');
    debugPrint('=== URL Parameters ===');
    if (widget.params != null && widget.params!.isNotEmpty) {
      widget.params!.forEach((key, value) {
        debugPrint('$key: $value');
      });
    } else {
      debugPrint('No parameters');
    }
    debugPrint('=============================');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OneCard 인증'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Icon(
              Icons.security,
              size: 100,
              color: Colors.black,
            ),
            const SizedBox(height: 30),
            Text(
              _isAuthenticated 
                  ? '인증이 완료되었습니다!' 
                  : '${_serviceId ?? '서비스'}에서 인증을 요청했어요!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (!_isAuthenticated) ...[
              const Text(
                'OneCard를 사용하여 안전하게 인증하세요',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const SizedBox(height: 10),
              const Text(
                '인증이 성공적으로 완료되었습니다',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const Spacer(),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : (_isAuthenticated ? _exitApp : _authenticateWithCard),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAuthenticated ? Colors.green : Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isAuthenticated ? '완료' : 'OneCard로 인증하기',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _authenticateWithCard() async {
    if (_data == null || _attemptId == null || _clientId == null) {
      setState(() {
        _errorMessage = '필수 인증 정보가 누락되었습니다.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // NFC 스캔 안내 다이얼로그 표시
      _showScanDialog();

      // data를 바이트 배열로 변환
      final dataBytes = NFCCardOperations.hexStringToBytes(_data!);
      
      if (dataBytes.length < 65) {
        throw Exception('데이터 길이가 부족합니다. 최소 65바이트 필요');
      }

      // hostPublicKey: data[:65], challenge: data[65:]
      final hostPublicKey = dataBytes.sublist(0, 65);
      final challenge = dataBytes.sublist(65);

      debugPrint('Host Public Key (65 bytes): ${NFCCardOperations.bytesToHexString(hostPublicKey)}');
      debugPrint('Challenge (${challenge.length} bytes): ${NFCCardOperations.bytesToHexString(challenge)}');

      // NFC 카드 인증 실행
      final result = await NFCCardOperations.authenticateCard(
        hostPublicKey: hostPublicKey,
        challenge: challenge,
      );

      Navigator.pop(context); // 스캔 다이얼로그 닫기

      if (result.isSuccess && result.data != null) {
        // 인증 성공 - 암호화된 데이터를 hex string으로 변환
        final cardDataHex = NFCCardOperations.bytesToHexString(result.data!.encryptedData);
        debugPrint('Card authentication successful. Data: $cardDataHex');

        // 서버로 카드 응답 전송
        final response = await AuthService.sendCardResponse(
          cardData: cardDataHex,
          attemptId: _attemptId!,
          clientId: _clientId!,
        );

        if (response != null && mounted) {
          setState(() {
            _isAuthenticated = true;
            _isLoading = false;
          });
          debugPrint('Authentication completed successfully');
        } else if (mounted) {
          setState(() {
            _errorMessage = '서버 응답 전송에 실패했습니다.';
            _isLoading = false;
          });
        }
      } else {
        String errorMessage = '카드 인증에 실패했습니다.';
        
        switch (result.status) {
          case NFCResponseStatus.pinRequired:
            errorMessage = 'PIN이 필요합니다.';
            break;
          case NFCResponseStatus.pinBlocked:
            errorMessage = 'PIN이 차단되었습니다.';
            break;
          case NFCResponseStatus.cardNotFound:
            errorMessage = '카드를 찾을 수 없습니다.';
            break;
          case NFCResponseStatus.communicationError:
            errorMessage = '카드 통신 오류가 발생했습니다.';
            break;
          default:
            errorMessage = result.errorMessage ?? '알 수 없는 오류가 발생했습니다.';
        }
        
        if (mounted) {
          setState(() {
            _errorMessage = errorMessage;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      Navigator.pop(context); // 스캔 다이얼로그 닫기
      if (mounted) {
        setState(() {
          _errorMessage = '인증 중 오류가 발생했습니다: $e';
          _isLoading = false;
        });
      }
      debugPrint('Authentication error: $e');
    }
  }

  void _showScanDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.nfc,
                size: 60,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              const Text(
                '카드 스캔',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'OneCard를 스마트폰 뒷면에\n가까이 대주세요',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: Colors.blue),
            ],
          ),
        );
      },
    );
  }

  void _exitApp() {
    // 앱 종료
    SystemNavigator.pop();
  }
}
