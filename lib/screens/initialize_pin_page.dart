import 'package:flutter/material.dart';
import '../NFCOperation.dart';

class InitializePinPage extends StatefulWidget {
  const InitializePinPage({super.key});

  @override
  State<InitializePinPage> createState() => _InitializePinPageState();
}

class _InitializePinPageState extends State<InitializePinPage> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('신규 사원증 사용등록'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.new_releases,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 30),
            const Text(
              '신규 사원증 사용등록',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '새로 발급받은 사원증의 초기 PIN을 설정하세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            
            // PIN 입력
            TextField(
              controller: _pinController,
              obscureText: _obscurePin,
              maxLength: 8,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: '새 PIN (4-8자리)',
                labelStyle: const TextStyle(color: Colors.black),
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
                prefixIcon: const Icon(Icons.lock, color: Colors.black),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePin ? Icons.visibility : Icons.visibility_off,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePin = !_obscurePin;
                    });
                  },
                ),
                counterText: '',
                helperText: '4자리 이상 8자리 이하의 숫자',
                helperStyle: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            
            // PIN 확인
            TextField(
              controller: _confirmPinController,
              obscureText: _obscureConfirmPin,
              maxLength: 8,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: 'PIN 확인',
                labelStyle: const TextStyle(color: Colors.black),
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
                prefixIcon: const Icon(Icons.lock, color: Colors.black),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPin ? Icons.visibility : Icons.visibility_off,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPin = !_obscureConfirmPin;
                    });
                  },
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 30),
            
            // PIN 등록 버튼
            ElevatedButton(
              onPressed: _isLoading ? null : _initializePin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('PIN 등록', style: TextStyle(fontSize: 16)),
            ),
            
            const SizedBox(height: 20),
            
            // 주의사항
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '신규 사원증 등록 안내',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• 새로 발급받은 사원증만 등록 가능합니다\n'
                    '• 이미 사용중인 사원증은 등록할 수 없습니다\n'
                    '• PIN은 4자리 이상 8자리 이하의 숫자만 가능합니다\n'
                    '• 등록된 PIN은 로그인 시 사용됩니다\n'
                    '• 카드 스캔 시 다른 NFC 앱은 종료됩니다',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 추가 안내
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '중요 사항',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• PIN을 분실하지 않도록 주의하세요\n'
                    '• PIN 입력 오류 시 카드가 차단될 수 있습니다\n'
                    '• 차단된 카드는 재발급을 받아야 합니다',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _initializePin() async {
    if (_pinController.text.isEmpty || _confirmPinController.text.isEmpty) {
      _showErrorDialog('모든 필드를 입력해주세요.');
      return;
    }

    if (_pinController.text.length < 4) {
      _showErrorDialog('PIN은 4자리 이상이어야 합니다.');
      return;
    }

    if (_pinController.text != _confirmPinController.text) {
      _showErrorDialog('PIN과 PIN 확인이 일치하지 않습니다.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // NFC 스캔 안내 다이얼로그 표시
      _showScanDialog();

      final result = await NFCCardOperations.initializePin(_pinController.text);

      Navigator.pop(context); // 스캔 다이얼로그 닫기

      if (result.isSuccess) {
        _showSuccessDialog();
      } else {
        String errorMessage = 'PIN 등록에 실패했습니다.';
        
        // 상태 워드가 9000이 아닌 경우 이미 등록된 카드로 판단
        if (result.statusWord != null && result.statusWord != 0x9000) {
          errorMessage = '이미 사용 등록되어 PIN을 등록할 수 없습니다.';
        } else {
          switch (result.status) {
            case NFCResponseStatus.cardNotFound:
              errorMessage = '카드를 찾을 수 없습니다. 카드를 다시 스캔해주세요.';
              break;
            case NFCResponseStatus.communicationError:
              errorMessage = '카드와의 통신에 실패했습니다.';
              break;
            case NFCResponseStatus.error:
              // 기본적으로 이미 등록된 카드로 처리
              errorMessage = '이미 사용 등록되어 PIN을 등록할 수 없습니다.';
              break;
            default:
              errorMessage = result.errorMessage ?? 'PIN 등록에 실패했습니다.';
          }
        }
        
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      Navigator.pop(context); // 스캔 다이얼로그 닫기
      _showErrorDialog('PIN 등록 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                '새로 발급받은 OneCard를\n스마트폰 뒷면에 가까이 대주세요',
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('등록 완료', style: TextStyle(color: Colors.black)),
            ],
          ),
          content: const Text(
            '신규 사원증 PIN이 성공적으로 등록되었습니다.\n이제 로그인에 사용할 수 있습니다.',
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // PIN 등록 화면 닫기
              },
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('오류', style: TextStyle(color: Colors.black)),
            ],
          ),
          content: Text(message, style: const TextStyle(color: Colors.black)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }
}
