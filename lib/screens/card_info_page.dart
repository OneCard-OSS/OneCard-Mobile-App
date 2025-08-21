import 'package:flutter/material.dart';
import '../NFCOperation.dart';

class CardInfoPage extends StatefulWidget {
  const CardInfoPage({super.key});

  @override
  State<CardInfoPage> createState() => _CardInfoPageState();
}

class _CardInfoPageState extends State<CardInfoPage> {
  bool _isLoading = false;
  CardInfo? _cardInfo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('카드 정보 조회'),
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
              Icons.credit_card,
              size: 80,
              color: Colors.black,
            ),
            const SizedBox(height: 30),
            const Text(
              '카드 정보',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 40),
            
            // 카드 정보 조회 버튼
            ElevatedButton(
              onPressed: _isLoading ? null : _getCardInfo,
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
                  : const Text('카드 정보 조회', style: TextStyle(fontSize: 16)),
            ),
            
            const SizedBox(height: 30),
            
            // 카드 정보 표시 영역
            if (_cardInfo != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          '카드 정보',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // 소유자 ID
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '소유자 ID:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _cardInfo!.ownerId.isEmpty ? '정보 없음' : _cardInfo!.ownerId,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // PIN 시도 횟수
                    Row(
                      children: [
                        Icon(
                          _cardInfo!.pinTriesRemaining > 0 
                              ? Icons.security 
                              : Icons.warning,
                          color: _cardInfo!.pinTriesRemaining > 0 
                              ? Colors.green 
                              : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'PIN 시도 가능 횟수:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _cardInfo!.pinTriesRemaining > 0 
                                ? Colors.green[100] 
                                : Colors.red[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_cardInfo!.pinTriesRemaining}회',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _cardInfo!.pinTriesRemaining > 0 
                                  ? Colors.green[800] 
                                  : Colors.red[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    if (_cardInfo!.pinTriesRemaining == 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'PIN이 차단되었습니다. 카드를 재발급받아야 합니다.',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_cardInfo!.pinTriesRemaining <= 2) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'PIN 시도 횟수가 얼마 남지 않았습니다. 주의하세요.',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            
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
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '안내사항',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• 카드 정보 조회를 위해 카드를 스캔해야 합니다\n'
                    '• 카드 스캔 시 다른 NFC 앱은 종료됩니다\n'
                    '• PIN 시도 횟수가 0이 되면 카드가 차단됩니다\n'
                    '• 차단된 카드는 재발급을 받아야 합니다',
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

  void _getCardInfo() async {
    setState(() {
      _isLoading = true;
      _cardInfo = null;
    });

    try {
      // NFC 스캔 안내 다이얼로그 표시
      _showScanDialog();

      final result = await NFCCardOperations.getCardInfo();

      Navigator.pop(context); // 스캔 다이얼로그 닫기

      if (result.isSuccess && result.data != null) {
        setState(() {
          _cardInfo = result.data;
        });
      } else {
        String errorMessage = '카드 정보 조회에 실패했습니다.';
        
        switch (result.status) {
          case NFCResponseStatus.cardNotFound:
            errorMessage = '카드를 찾을 수 없습니다. 카드를 다시 스캔해주세요.';
            break;
          case NFCResponseStatus.communicationError:
            errorMessage = '카드와의 통신에 실패했습니다.';
            break;
          case NFCResponseStatus.error:
            errorMessage = '카드 읽기 중 오류가 발생했습니다.';
            break;
          default:
            errorMessage = result.errorMessage ?? '카드 정보 조회에 실패했습니다.';
        }
        
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      Navigator.pop(context); // 스캔 다이얼로그 닫기
      _showErrorDialog('카드 정보 조회 중 오류가 발생했습니다: $e');
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
}
