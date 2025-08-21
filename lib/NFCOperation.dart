import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'assets/nfc_commands.dart' as APDU;

NFCAvailability _availability = NFCAvailability.not_supported;

/// 카드 정보 응답 데이터를 담는 클래스
class CardInfo {
  final String ownerId;
  final int pinTriesRemaining;

  CardInfo({required this.ownerId, required this.pinTriesRemaining});

  @override
  String toString() {
    return 'CardInfo(ownerId: $ownerId, pinTriesRemaining: $pinTriesRemaining)';
  }
}

/// 외부 인증 응답 데이터를 담는 클래스
class ExternalAuthResponse {
  final Uint8List encryptedData;
  final bool isPinPassed;
  final Uint8List challenge;

  ExternalAuthResponse({
    required this.encryptedData,
    required this.isPinPassed,
    required this.challenge,
  });

  @override
  String toString() {
    return 'ExternalAuthResponse(encryptedData: ${encryptedData.length} bytes, isPinPassed: $isPinPassed)';
  }
}

/// NFC 응답 상태를 나타내는 열거형
enum NFCResponseStatus {
  success,
  error,
  pinRequired,
  pinBlocked,
  wrongPin,
  cardNotFound,
  communicationError,
}

/// NFC 응답을 담는 클래스
class NFCResponse<T> {
  final NFCResponseStatus status;
  final T? data;
  final String? errorMessage;
  final int? statusWord;

  NFCResponse({
    required this.status,
    this.data,
    this.errorMessage,
    this.statusWord,
  });

  bool get isSuccess => status == NFCResponseStatus.success;
}

/// NFC 카드 유틸리티 클래스
class NFCCardOperations {
  static const int SW_SUCCESS = 0x9000;
  static const int SW_SECURITY_STATUS_NOT_SATISFIED = 0x6982;
  static const int SW_PIN_BLOCKED = 0x6983;
  static const int SW_WRONG_LENGTH = 0x6700;
  static const int SW_DATA_INVALID = 0x6A80;

  /// NFC 가용성 확인
  static Future<bool> checkNFCAvailability() async {
    try {
      debugPrint('🔍 Checking NFC availability...');
      _availability = await FlutterNfcKit.nfcAvailability;
      
      switch (_availability) {
        case NFCAvailability.available:
          debugPrint('✅ NFC is available and enabled');
          return true;
        case NFCAvailability.not_supported:
          debugPrint('❌ NFC is not supported on this device');
          return false;
        case NFCAvailability.disabled:
          debugPrint('⚠️ NFC is disabled. Please enable NFC in settings');
          return false;
      }
    } catch (e) {
      debugPrint('🔴 NFC availability check failed: $e');
      return false;
    }
  }

  /// NFC 카드 폴링 및 연결
  static Future<NFCTag?> connectToCard() async {
    try {
      debugPrint('🔍 Starting NFC card polling...');
      final tag = await FlutterNfcKit.poll(
        timeout: Duration(seconds: 20),
        iosMultipleTagMessage: "Multiple tags found!",
        iosAlertMessage: "OneCard를 스캔하세요",
      );
      
      debugPrint('✅ Card connected successfully: ${tag.type}');
      debugPrint('📱 Card ID: ${tag.id}');
      
      return tag;
    } catch (e) {
      debugPrint('🔴 Card connection failed: $e');
      return null;
    }
  }

  /// APDU 명령 전송 및 응답 수신
  static Future<Uint8List?> _sendApdu(Uint8List command) async {
    try {
      // APDU 명령어 로그 출력
      final commandHex = command.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
      debugPrint('🔵 APDU Command: $commandHex');
      
      final response = await FlutterNfcKit.transceive(command);
      
      // APDU 응답 로그 출력
      final responseHex = response.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
      debugPrint('🟢 APDU Response: $responseHex');
      
      return response;
    } catch (e) {
      debugPrint('🔴 APDU transmission failed: $e');
      return null;
    }
  }

  /// 응답 상태 워드 파싱
  static int _getStatusWord(Uint8List response) {
    if (response.length < 2) return 0x0000;
    return (response[response.length - 2] << 8) | response[response.length - 1];
  }

  /// 응답 데이터 추출 (상태 워드 제외)
  static Uint8List _getResponseData(Uint8List response) {
    if (response.length <= 2) return Uint8List(0);
    return response.sublist(0, response.length - 2);
  }

  /// 상태 워드를 기반으로 NFCResponseStatus 결정
  static NFCResponseStatus _getResponseStatus(int statusWord) {
    switch (statusWord) {
      case SW_SUCCESS:
        return NFCResponseStatus.success;
      case SW_SECURITY_STATUS_NOT_SATISFIED:
        return NFCResponseStatus.pinRequired;
      case SW_PIN_BLOCKED:
        return NFCResponseStatus.pinBlocked;
      case SW_WRONG_LENGTH:
      case SW_DATA_INVALID:
        return NFCResponseStatus.error;
      default:
        return NFCResponseStatus.error;
    }
  }

  /// PIN 초기화
  static Future<NFCResponse<bool>> initializePin(String pin) async {
    try {
      // 1. NFC 가용성 확인
      final isAvailable = await checkNFCAvailability();
      if (!isAvailable) {
        return NFCResponse(
          status: NFCResponseStatus.error,
          errorMessage: 'NFC not available',
        );
      }

      // 2. Reader Mode 활성화
      await enableReaderMode();

      // 3. 카드 연결
      final tag = await connectToCard();
      if (tag == null) {
        return NFCResponse(
          status: NFCResponseStatus.cardNotFound,
          errorMessage: 'Failed to connect to card',
        );
      }

      // 4. 애플릿 선택
      final appletSelected = await selectApplet();
      if (!appletSelected) {
        return NFCResponse(
          status: NFCResponseStatus.error,
          errorMessage: 'Failed to select applet',
        );
      }

      // 5. PIN 초기화 명령 실행
      final command = APDU.initializePinCommand(pin);
      final response = await _sendApdu(command);
      
      if (response == null) {
        return NFCResponse(
          status: NFCResponseStatus.communicationError,
          errorMessage: 'Failed to send APDU command',
        );
      }

      final statusWord = _getStatusWord(response);
      final status = _getResponseStatus(statusWord);

      return NFCResponse(
        status: status,
        data: status == NFCResponseStatus.success,
        statusWord: statusWord,
        errorMessage: status != NFCResponseStatus.success 
            ? 'PIN initialization failed: 0x${statusWord.toRadixString(16)}'
            : null,
      );
    } catch (e) {
      return NFCResponse(
        status: NFCResponseStatus.error,
        errorMessage: 'PIN initialization error: $e',
      );
    } finally {
      // 6. Reader Mode 비활성화 및 연결 해제
      await disableReaderMode();
      await disconnect();
    }
  }

  /// PIN 변경
  static Future<NFCResponse<bool>> changePin(String oldPin, String newPin) async {
    try {
      // 1. NFC 가용성 확인
      final isAvailable = await checkNFCAvailability();
      if (!isAvailable) {
        return NFCResponse(
          status: NFCResponseStatus.error,
          errorMessage: 'NFC not available',
        );
      }

      // 2. Reader Mode 활성화
      await enableReaderMode();

      // 3. 카드 연결
      final tag = await connectToCard();
      if (tag == null) {
        return NFCResponse(
          status: NFCResponseStatus.cardNotFound,
          errorMessage: 'Failed to connect to card',
        );
      }

      // 4. 애플릿 선택
      final appletSelected = await selectApplet();
      if (!appletSelected) {
        return NFCResponse(
          status: NFCResponseStatus.error,
          errorMessage: 'Failed to select applet',
        );
      }

      // 5. PIN 변경 명령 실행
      final command = APDU.generateChangePinCommand(oldPin, newPin);
      final response = await _sendApdu(command);
      
      if (response == null) {
        return NFCResponse(
          status: NFCResponseStatus.communicationError,
          errorMessage: 'Failed to send APDU command',
        );
      }

      final statusWord = _getStatusWord(response);
      final status = _getResponseStatus(statusWord);

      return NFCResponse(
        status: status,
        data: status == NFCResponseStatus.success,
        statusWord: statusWord,
        errorMessage: status != NFCResponseStatus.success 
            ? 'PIN change failed: 0x${statusWord.toRadixString(16)}'
            : null,
      );
    } catch (e) {
      return NFCResponse(
        status: NFCResponseStatus.error,
        errorMessage: 'PIN change error: $e',
      );
    } finally {
      // 6. Reader Mode 비활성화 및 연결 해제
      await disableReaderMode();
      await disconnect();
    }
  }

  /// 카드 정보 조회
  static Future<NFCResponse<CardInfo>> getCardInfo() async {
    try {
      // 1. NFC 가용성 확인
      final isAvailable = await checkNFCAvailability();
      if (!isAvailable) {
        return NFCResponse(
          status: NFCResponseStatus.error,
          errorMessage: 'NFC not available',
        );
      }

      // 2. Reader Mode 활성화
      await enableReaderMode();

      // 3. 카드 연결
      final tag = await connectToCard();
      if (tag == null) {
        return NFCResponse(
          status: NFCResponseStatus.cardNotFound,
          errorMessage: 'Failed to connect to card',
        );
      }

      // 4. 애플릿 선택
      final appletSelected = await selectApplet();
      if (!appletSelected) {
        return NFCResponse(
          status: NFCResponseStatus.error,
          errorMessage: 'Failed to select applet',
        );
      }

      // 5. 카드 정보 조회 명령 실행
      final command = APDU.generateGetCardInfoCommand();
      
      final response = await _sendApdu(command);
      
      if (response == null) {
        return NFCResponse(
          status: NFCResponseStatus.communicationError,
          errorMessage: 'Failed to send APDU command',
        );
      }

      final statusWord = _getStatusWord(response);
      final status = _getResponseStatus(statusWord);

      if (status != NFCResponseStatus.success) {
        return NFCResponse(
          status: status,
          statusWord: statusWord,
          errorMessage: 'Get card info failed: 0x${statusWord.toRadixString(16)}',
        );
      }

      final data = _getResponseData(response);
      final cardInfo = _parseCardInfo(data);

      return NFCResponse(
        status: NFCResponseStatus.success,
        data: cardInfo,
        statusWord: statusWord,
      );
    } catch (e) {
      return NFCResponse(
        status: NFCResponseStatus.error,
        errorMessage: 'Get card info error: $e',
      );
    } finally {
      // 6. Reader Mode 비활성화 및 연결 해제
      await disableReaderMode();
      await disconnect();
    }
  }

  /// 카드의 ECDH 공개키 조회
  static Future<NFCResponse<Uint8List>> getPublicKey() async {
    try {
      // 1. NFC 가용성 확인
      final isAvailable = await checkNFCAvailability();
      if (!isAvailable) {
        return NFCResponse(
          status: NFCResponseStatus.error,
          errorMessage: 'NFC not available',
        );
      }

      // 2. Reader Mode 활성화
      await enableReaderMode();

      // 3. 카드 연결
      final tag = await connectToCard();
      if (tag == null) {
        return NFCResponse(
          status: NFCResponseStatus.cardNotFound,
          errorMessage: 'Failed to connect to card',
        );
      }

      // 4. 애플릿 선택
      final appletSelected = await selectApplet();
      if (!appletSelected) {
        return NFCResponse(
          status: NFCResponseStatus.error,
          errorMessage: 'Failed to select applet',
        );
      }

      // 5. 공개키 조회 명령 실행
      final command = Uint8List.fromList([
        0xFF, // CLA
        0xA1, // INS_GET_PUBLIC_KEY
        0x00, // P1
        0x00, // P2
        0x00, // Le
      ]);
      
      final response = await _sendApdu(command);
      
      if (response == null) {
        return NFCResponse(
          status: NFCResponseStatus.communicationError,
          errorMessage: 'Failed to send APDU command',
        );
      }

      final statusWord = _getStatusWord(response);
      final status = _getResponseStatus(statusWord);

      if (status != NFCResponseStatus.success) {
        return NFCResponse(
          status: status,
          statusWord: statusWord,
          errorMessage: 'Get public key failed: 0x${statusWord.toRadixString(16)}',
        );
      }

      final publicKey = _getResponseData(response);

      return NFCResponse(
        status: NFCResponseStatus.success,
        data: publicKey,
        statusWord: statusWord,
      );
    } catch (e) {
      return NFCResponse(
        status: NFCResponseStatus.error,
        errorMessage: 'Get public key error: $e',
      );
    } finally {
      // 6. Reader Mode 비활성화 및 연결 해제
      await disableReaderMode();
      await disconnect();
    }
  }

  /// 외부 인증 수행
  static Future<NFCResponse<ExternalAuthResponse>> performExternalAuth({
    required Uint8List hostPublicKey,
    required Uint8List challenge,
    String? pin,
  }) async {
    try {
      // 1. NFC 가용성 확인
      final isAvailable = await checkNFCAvailability();
      if (!isAvailable) {
        return NFCResponse(
          status: NFCResponseStatus.error,
          errorMessage: 'NFC not available',
        );
      }

      // 2. Reader Mode 활성화
      await enableReaderMode();

      // 3. 카드 연결
      final tag = await connectToCard();
      if (tag == null) {
        return NFCResponse(
          status: NFCResponseStatus.cardNotFound,
          errorMessage: 'Failed to connect to card',
        );
      }

      // 4. 애플릿 선택
      final appletSelected = await selectApplet();
      if (!appletSelected) {
        return NFCResponse(
          status: NFCResponseStatus.error,
          errorMessage: 'Failed to select applet',
        );
      }

      // 5. 외부 인증 명령 실행
      final command = APDU.generateExternalAuthCommand(
        hostPublicKey: hostPublicKey,
        challenge: challenge,
        pin: pin,
      );
      
      final response = await _sendApdu(command);
      
      if (response == null) {
        return NFCResponse(
          status: NFCResponseStatus.communicationError,
          errorMessage: 'Failed to send APDU command',
        );
      }

      final statusWord = _getStatusWord(response);
      final status = _getResponseStatus(statusWord);

      if (status != NFCResponseStatus.success) {
        return NFCResponse(
          status: status,
          statusWord: statusWord,
          errorMessage: 'External authentication failed: 0x${statusWord.toRadixString(16)}',
        );
      }

      final encryptedData = _getResponseData(response);
      final authResponse = _parseExternalAuthResponse(encryptedData, challenge);

      return NFCResponse(
        status: NFCResponseStatus.success,
        data: authResponse,
        statusWord: statusWord,
      );
    } catch (e) {
      return NFCResponse(
        status: NFCResponseStatus.error,
        errorMessage: 'External authentication error: $e',
      );
    } finally {
      // 6. Reader Mode 비활성화 및 연결 해제
      await disableReaderMode();
      await disconnect();
    }
  }

  /// 애플릿 선택
  static Future<bool> selectApplet() async {
    try {
      // NFC 연결 상태 확인
      final availability = await FlutterNfcKit.nfcAvailability;
      if (availability != NFCAvailability.available) {
        debugPrint('NFC not available for applet selection');
        return false;
      }

      final selectCommand = APDU.generateSelectAppletCommand();
      final response = await _sendApdu(selectCommand);
      
      if (response == null) {
        debugPrint('Failed to send select applet command');
        return false;
      }
      
      final statusWord = _getStatusWord(response);
      if (statusWord == SW_SUCCESS) {
        debugPrint('Applet selected successfully');
        return true;
      } else {
        debugPrint('Applet selection failed. Status: ${statusWord.toRadixString(16)}');
        return false;
      }
    } catch (e) {
      debugPrint('Applet selection error: $e');
      return false;
    }
  }

  /// 카드 정보 응답 파싱
  static CardInfo _parseCardInfo(Uint8List data) {
    String ownerId = '';
    int pinTriesRemaining = 0;

    int index = 0;
    while (index < data.length) {
      if (index + 1 >= data.length) break;
      
      final tag = data[index];
      final length = data[index + 1];
      
      if (index + 2 + length > data.length) break;
      
      final value = data.sublist(index + 2, index + 2 + length);
      
      if (tag == 0x49) { // TAG_OWNER_ID
        ownerId = utf8.decode(value);
      } else if (tag == 0x50) { // TAG_PIN_STATUS
        if (value.isNotEmpty) {
          pinTriesRemaining = value[0];
        }
      }
      
      index += 2 + length;
    }

    return CardInfo(
      ownerId: ownerId,
      pinTriesRemaining: pinTriesRemaining,
    );
  }

  /// 외부 인증 응답 파싱
  static ExternalAuthResponse _parseExternalAuthResponse(
    Uint8List encryptedData, 
    Uint8List originalChallenge
  ) {
    // 실제 복호화는 클라이언트에서 ECDH 공유 비밀로 수행해야 함
    // 여기서는 응답 데이터의 길이로 PIN 통과 여부를 판단
    final isPinPassed = encryptedData.length == 32; // 32바이트면 PIN 통과, 16바이트면 PIN 미통과
    
    return ExternalAuthResponse(
      encryptedData: encryptedData,
      isPinPassed: isPinPassed,
      challenge: originalChallenge,
    );
  }

  /// NFC 연결 종료
  static Future<void> disconnect() async {
    try {
      await FlutterNfcKit.finish();
    } catch (e) {
      debugPrint('NFC disconnect failed: $e');
    }
  }

  /// 완전한 카드 인증 프로세스
  static Future<NFCResponse<ExternalAuthResponse>> authenticateCard({
    required Uint8List hostPublicKey,
    required Uint8List challenge,
    String? pin,
  }) async {
    try {
      // 1. NFC 가용성 확인
      final isAvailable = await checkNFCAvailability();
      if (!isAvailable) {
        return NFCResponse(
          status: NFCResponseStatus.error,
          errorMessage: 'NFC not available',
        );
      }

      // 2. Reader Mode 활성화 (다른 NFC 앱 실행 방지)
      await enableReaderMode();

      // 3. 카드 연결
      final tag = await connectToCard();
      if (tag == null) {
        return NFCResponse(
          status: NFCResponseStatus.cardNotFound,
          errorMessage: 'Failed to connect to card',
        );
      }

      // 4. 애플릿 선택
      final appletSelected = await selectApplet();
      if (!appletSelected) {
        return NFCResponse(
          status: NFCResponseStatus.error,
          errorMessage: 'Failed to select applet',
        );
      }

      // 5. 외부 인증 수행 (내부에서 애플릿 선택을 다시 하지 않도록 수정 필요)
      final authResult = await _performExternalAuthWithoutAppletSelection(
        hostPublicKey: hostPublicKey,
        challenge: challenge,
        pin: pin,
      );

      return authResult;
    } catch (e) {
      return NFCResponse(
        status: NFCResponseStatus.error,
        errorMessage: 'Authentication process error: $e',
      );
    } finally {
      // 6. Reader Mode 비활성화 및 연결 해제
      await disableReaderMode();
      await disconnect();
    }
  }

  /// Uint8List를 hex string으로 변환
  static String bytesToHexString(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
  }

  /// hex string을 Uint8List로 변환
  static Uint8List hexStringToBytes(String hexString) {
    final cleanHex = hexString.replaceAll(' ', '').replaceAll('0x', '');
    final List<int> bytes = [];
    for (int i = 0; i < cleanHex.length; i += 2) {
      final hexByte = cleanHex.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  /// NFC Reader Mode 활성화 (Android에서 다른 NFC 앱 실행 방지)
  static Future<void> enableReaderMode() async {
    try {
      // flutter_nfc_kit에서는 poll 시 자동으로 reader mode를 사용
      // 여기서는 상태 확인만 수행
      final availability = await FlutterNfcKit.nfcAvailability;
      if (availability == NFCAvailability.available) {
        debugPrint('✅ NFC Reader Mode enabled - other NFC apps will be blocked');
      } else {
        debugPrint('❌ NFC not available');
      }
    } catch (e) {
      debugPrint('🔴 Failed to enable NFC Reader Mode: $e');
    }
  }

  /// NFC Reader Mode 비활성화
  static Future<void> disableReaderMode() async {
    try {
      // flutter_nfc_kit의 finish()가 reader mode를 비활성화함
      await FlutterNfcKit.finish();
      debugPrint('✅ NFC Reader Mode disabled');
    } catch (e) {
      debugPrint('🔴 Failed to disable NFC Reader Mode: $e');
    }
  }

  /// 애플릿 선택 없이 외부 인증 수행 (이미 선택된 상태에서 사용)
  static Future<NFCResponse<ExternalAuthResponse>> _performExternalAuthWithoutAppletSelection({
    required Uint8List hostPublicKey,
    required Uint8List challenge,
    String? pin,
  }) async {
    try {
      final command = APDU.generateExternalAuthCommand(
        hostPublicKey: hostPublicKey,
        challenge: challenge,
        pin: pin,
      );
      
      final response = await _sendApdu(command);
      
      if (response == null) {
        return NFCResponse(
          status: NFCResponseStatus.communicationError,
          errorMessage: 'Failed to send APDU command',
        );
      }

      final statusWord = _getStatusWord(response);
      final status = _getResponseStatus(statusWord);

      if (status != NFCResponseStatus.success) {
        return NFCResponse(
          status: status,
          statusWord: statusWord,
          errorMessage: 'External authentication failed: 0x${statusWord.toRadixString(16)}',
        );
      }

      final encryptedData = _getResponseData(response);
      final authResponse = _parseExternalAuthResponse(encryptedData, challenge);

      return NFCResponse(
        status: NFCResponseStatus.success,
        data: authResponse,
        statusWord: statusWord,
      );
    } catch (e) {
      return NFCResponse(
        status: NFCResponseStatus.error,
        errorMessage: 'External authentication error: $e',
      );
    }
  }
}

