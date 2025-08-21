import 'package:flutter/material.dart';
import '../NFCOperation.dart';

class ChangePinPage extends StatefulWidget {
  const ChangePinPage({super.key});

  @override
  State<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends State<ChangePinPage> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;
  bool _obscureOldPin = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PIN 변경'),
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
              Icons.security,
              size: 80,
              color: Colors.black,
            ),
            const SizedBox(height: 30),
            const Text(
              'PIN 변경',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 40),
            
            // 현재 PIN 입력
            TextField(
              controller: _oldPinController,
              obscureText: _obscureOldPin,
              maxLength: 8,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: '현재 PIN',
                labelStyle: const TextStyle(color: Colors.black),
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.black),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureOldPin ? Icons.visibility : Icons.visibility_off,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureOldPin = !_obscureOldPin;
                    });
                  },
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            
            // 새 PIN 입력
            TextField(
              controller: _newPinController,
              obscureText: _obscureNewPin,
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
                    _obscureNewPin ? Icons.visibility : Icons.visibility_off,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNewPin = !_obscureNewPin;
                    });
                  },
                ),
                counterText: '',
                helperText: '4자리 이상 8자리 이하의 숫자',
                helperStyle: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            
            // 새 PIN 확인
            TextField(
              controller: _confirmPinController,
              obscureText: _obscureConfirmPin,
              maxLength: 8,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: '새 PIN 확인',
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
            
            // PIN 변경 버튼
            ElevatedButton(
              onPressed: _isLoading ? null : _changePin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('PIN 변경', style: TextStyle(fontSize: 16)),
            ),
            
            const SizedBox(height: 20),
            
            // 주의사항
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '주의사항',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• PIN 변경을 위해 카드를 스캔해야 합니다\n'
                    '• 카드 스캔 시 다른 NFC 앱은 종료됩니다\n'
                    '• PIN은 4자리 이상 8자리 이하의 숫자만 가능합니다\n'
                    '• 변경된 PIN은 즉시 적용됩니다',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
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

  void _changePin() async {
    if (_oldPinController.text.isEmpty ||
        _newPinController.text.isEmpty ||
        _confirmPinController.text.isEmpty) {
      _showErrorDialog('모든 필드를 입력해주세요.');
      return;
    }

    if (_newPinController.text.length < 4) {
      _showErrorDialog('새 PIN은 4자리 이상이어야 합니다.');
      return;
    }

    if (_newPinController.text != _confirmPinController.text) {
      _showErrorDialog('새 PIN과 PIN 확인이 일치하지 않습니다.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // NFC 스캔 안내 다이얼로그 표시
      _showScanDialog();

      final result = await NFCCardOperations.changePin(
        _oldPinController.text,
        _newPinController.text,
      );

      Navigator.pop(context); // 스캔 다이얼로그 닫기

      if (result.isSuccess) {
        _showSuccessDialog();
      } else {
        String errorMessage = 'PIN 변경에 실패했습니다.';
        
        switch (result.status) {
          case NFCResponseStatus.pinRequired:
            errorMessage = '현재 PIN이 올바르지 않습니다.';
            break;
          case NFCResponseStatus.pinBlocked:
            errorMessage = 'PIN이 차단되었습니다. 카드를 재발급받아야 합니다.';
            break;
          case NFCResponseStatus.cardNotFound:
            errorMessage = '카드를 찾을 수 없습니다. 카드를 다시 스캔해주세요.';
            break;
          case NFCResponseStatus.communicationError:
            errorMessage = '카드와의 통신에 실패했습니다.';
            break;
          default:
            errorMessage = result.errorMessage ?? 'PIN 변경에 실패했습니다.';
        }
        
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      Navigator.pop(context); // 스캔 다이얼로그 닫기
      _showErrorDialog('PIN 변경 중 오류가 발생했습니다: $e');
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
              Text('성공', style: TextStyle(color: Colors.black)),
            ],
          ),
          content: const Text(
            'PIN이 성공적으로 변경되었습니다.',
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // PIN 변경 화면 닫기
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
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }
}
