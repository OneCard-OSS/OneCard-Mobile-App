import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../NFCOperation.dart';
import '../utils/hex_utils.dart';
import 'initialize_pin_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _empNoController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _sessionExpiredMessage;

  @override
  void initState() {
    super.initState();
    _attemptAutoLogin();
  }

  /// 자동 로그인 시도
  Future<void> _attemptAutoLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _sessionExpiredMessage = null;
    });

    try {
      final success = await AuthService.attemptAutoLogin();
      if (success) {
        debugPrint('Auto login successful');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/main');
        }
        return;
      }

      // 자동 로그인 실패시 세션 만료 메시지 표시
      setState(() {
        _sessionExpiredMessage = '로그인이 필요합니다.';
      });

    } catch (e) {
      debugPrint('Auto login error: $e');
      setState(() {
        _errorMessage = '자동 로그인 중 오류가 발생했습니다.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 수동 로그인 처리
  Future<void> _handleLogin() async {
    if (_empNoController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '사번을 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _sessionExpiredMessage = null;
    });

    try {
      // 1단계: 로그인 시작
      final initiateResult = await AuthService.initiateLogin(_empNoController.text.trim());
      if (initiateResult == null) {
        setState(() {
          _errorMessage = '로그인 요청에 실패했습니다. 네트워크를 확인해주세요.';
        });
        return;
      }

      final attemptId = initiateResult['attempt_id'] as String?;
      final responseData = initiateResult['response'] as String?;

      if (attemptId == null || responseData == null) {
        setState(() {
          _errorMessage = '서버 응답이 올바르지 않습니다.';
        });
        return;
      }

      // 2단계: NFC 카드 인증 수행
      final nfcAuthResult = await _performNFCAuthentication(responseData);
      if (nfcAuthResult == null) {
        setState(() {
          _errorMessage = 'NFC 카드 인증에 실패했습니다.';
        });
        return;
      }

      // 3단계: 로그인 검증
      final verifyResult = await AuthService.verifyLogin(
        attemptId: attemptId,
        encryptedData: nfcAuthResult['encryptedData']!,
      );

      if (verifyResult != null && verifyResult.containsKey('access_token')) {
        debugPrint('Login successful');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/main');
        }
      } else {
        setState(() {
          _errorMessage = '로그인 검증에 실패했습니다.';
        });
      }

    } catch (e) {
      debugPrint('Login error: $e');
      setState(() {
        _errorMessage = '로그인 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// NFC 카드 인증 수행
  Future<Map<String, String>?> _performNFCAuthentication(String responseData) async {
    try {
      // response 데이터를 hex string에서 바이트로 변환
      final responseBytes = HexUtils.hexStringToBytes(responseData);
      debugPrint('Response data length: ${responseBytes.length} bytes');
      
      if (responseBytes.length < 81) {
        debugPrint('Invalid response data length: ${responseBytes.length}, expected at least 81 bytes');
        return null;
      }

      // response[:65]는 hostPublicKey, response[65:81]은 challenge
      final hostPublicKey = responseBytes.sublist(0, 65);
      final challenge = responseBytes.sublist(65, 81);

      debugPrint('Host public key length: ${hostPublicKey.length}');
      debugPrint('Challenge length: ${challenge.length}');

      // UI 업데이트를 위한 작은 딜레이
      await Future.delayed(const Duration(milliseconds: 100));

      // NFC 카드 태그 요구 다이얼로그 표시
      if (mounted) {
        _showNFCDialogNonBlocking();
      }

      // UI가 렌더링될 시간 제공
      await Future.delayed(const Duration(milliseconds: 300));

      // NFC 카드 인증 수행 (비동기로 처리)
      final authResult = await _performNFCAuthenticationAsync(hostPublicKey, challenge);

      if (!authResult.isSuccess || authResult.data == null) {
        throw Exception(authResult.errorMessage ?? 'NFC authentication failed');
      }

      final encryptedData = authResult.data!.encryptedData;

      // 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 결과를 hex string으로 변환하여 반환
      return {
        'encryptedData': HexUtils.bytesToHexString(encryptedData),
      };

    } catch (e) {
      // 다이얼로그가 열려있으면 닫기
      if (mounted) {
        Navigator.of(context).pop();
      }
      debugPrint('NFC authentication error: $e');
      rethrow;
    } finally {
      ;
    }
  }

  /// 비동기 NFC 인증 수행
  Future<NFCResponse<ExternalAuthResponse>> _performNFCAuthenticationAsync(
    Uint8List hostPublicKey, 
    Uint8List challenge
  ) async {
    return await NFCCardOperations.authenticateCard(
      hostPublicKey: hostPublicKey,
      challenge: challenge,
    );
  }

  /// 논블로킹 NFC 다이얼로그 표시
  void _showNFCDialogNonBlocking() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false, // 백 버튼 비활성화
          child: AlertDialog(
            backgroundColor: Colors.white,
            title: const Row(
              children: [
                SizedBox(width: 8),
                Text('NFC 카드 인증', style: TextStyle(color: Colors.black)),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 16),
                CircularProgressIndicator(color: Colors.black),
                SizedBox(height: 16),
                Text(
                  'OneCard를 휴대폰 뒷면에 가까이 대주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
                SizedBox(height: 8),
                Text(
                  '카드를 태그하는 동안 움직이지 마세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _errorMessage = '사용자가 NFC 인증을 취소했습니다.';
                    });
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: const Text('취소'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text(
                'OneCard',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '온/오프라인 통합 보안 관제 서비스',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),

              // 세션 만료 메시지
              if (_sessionExpiredMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _sessionExpiredMessage!,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 사번 입력
              TextField(
                controller: _empNoController,
                decoration: const InputDecoration(
                  labelText: '사번',
                  hintText: '사번을 입력하세요',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                  labelStyle: TextStyle(color: Colors.black),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                ),
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),

              // 로그인 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'OneCard로 로그인',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 16),

              // 에러 메시지
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),
              
              // 신규 발급 사원증 사용등록 링크
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const InitializePinPage(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  ),
                  child: const Text(
                    '신규 발급 사원증 사용등록',
                    style: TextStyle(
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _empNoController.dispose();
    super.dispose();
  }
}
