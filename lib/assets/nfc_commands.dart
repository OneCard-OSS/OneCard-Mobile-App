import 'dart:convert';
import 'dart:typed_data';

/// PIN을 처음 등록(초기화)하기 위한 APDU 명령어를 생성합니다.
///
/// 애플릿 코드의 `initializePin` 함수에 해당합니다.
/// 데이터(C-DATA)는 LV(Length-Value) 형식입니다.
///
/// [pin]: 등록할 4~8자리 PIN 문자열
Uint8List initializePinCommand(String pin) {
  // PIN 길이 유효성 검사 (애플릿의 MIN_PIN_SIZE, MAX_PIN_SIZE 제약조건)
  if (pin.length < 4 || pin.length > 8) {
    throw ArgumentError('PIN must be between 4 and 8 characters long.');
  }

  final List<int> pinBytes = utf8.encode(pin);
  final int pinLength = pinBytes.length;

  // C-DATA 생성: [PIN 길이, ...PIN 바이트]
  final List<int> cdata = [pinLength, ...pinBytes];

  // APDU 명령어 생성: [CLA, INS, P1, P2, Lc, ...C-DATA]
  return Uint8List.fromList([
    0xFF, // CLA
    0x10, // INS_INIT_OWNERPIN
    0x00, // P1
    0x00, // P2
    cdata.length, // Lc
    ...cdata,
  ]);
}

/// 기존 PIN을 새로운 PIN으로 변경하기 위한 APDU 명령어를 생성합니다.
///
/// 애플릿 코드의 `changePin` 함수에 해당합니다.
/// 데이터(C-DATA)는 LV(기존 PIN)와 LV(새 PIN)가 연달아 오는 형식입니다.
///
/// [oldPin]: 기존 PIN 문자열
/// [newPin]: 변경할 4~8자리 PIN 문자열
Uint8List generateChangePinCommand(String oldPin, String newPin) {
  // 새 PIN 길이 유효성 검사
  if (newPin.length < 4 || newPin.length > 8) {
    throw ArgumentError('New PIN must be between 4 and 8 characters long.');
  }

  final List<int> oldPinBytes = utf8.encode(oldPin);
  final int oldPinLength = oldPinBytes.length;

  final List<int> newPinBytes = utf8.encode(newPin);
  final int newPinLength = newPinBytes.length;

  // C-DATA 생성: [기존 PIN 길이, ...기존 PIN], [새 PIN 길이, ...새 PIN]
  final List<int> cdata = [
    oldPinLength,
    ...oldPinBytes,
    newPinLength,
    ...newPinBytes,
  ];

  // APDU 명령어 생성: [CLA, INS, P1, P2, Lc, ...C-DATA]
  return Uint8List.fromList([
    0xFF, // CLA
    0x11, // INS_CHANGE_OWNERPIN
    0x00, // P1
    0x00, // P2
    cdata.length, // Lc
    ...cdata,
  ]);
}

/// 외부 인증을 수행하기 위한 APDU 명령어를 생성합니다.
///
/// 애플릿 코드의 `doExternalAuth` 함수에 해당합니다.
///
/// [hostPublicKey]: 호스트가 로그인 세션에 대해 생성한 ECDH 공개키 (uncompressed, 65바이트)
/// [challenge]: 호스트가 생성한 챌린지 (16바이트)
/// [pin]: (선택) 인증 과정에 사용할 사용자 PIN. null이 아니면 C-DATA에 PIN 정보가 TLV 형식으로 추가됩니다.
Uint8List generateExternalAuthCommand({
  required Uint8List hostPublicKey,
  required Uint8List challenge,
  String? pin,
}) {
  // 입력값 길이 유효성 검사
  if (hostPublicKey.length != 65) {
    throw ArgumentError('Host public key must be 65 bytes long.');
  }
  if (challenge.length != 16) {
    throw ArgumentError('Challenge must be 16 bytes long.');
  }

  // 기본 C-DATA 구성: [호스트 공개키, ...챌린지]
  final List<int> cdata = [...hostPublicKey, ...challenge];

  // PIN이 제공된 경우 TLV 형식으로 추가
  if (pin != null) {
    if (pin.length < 4 || pin.length > 8) {
      throw ArgumentError('PIN must be between 4 and 8 characters long.');
    }
    final List<int> pinBytes = utf8.encode(pin);
    final int pinLength = pinBytes.length;

    // PIN TLV: [Tag(0x50), Length, ...Value]
    final List<int> pinTlv = [0x50, pinLength, ...pinBytes];
    cdata.addAll(pinTlv);
  }

  // APDU 명령어 생성: [CLA, INS, P1, P2, Lc, ...C-DATA, Le]
  return Uint8List.fromList([
    0xFF, // CLA
    0xA3, // INS_EXT_AUTHENTICATE
    0x00, // P1
    0x00, // P2
    cdata.length, // Lc
    ...cdata,
    0x00, // Le (응답 데이터 길이를 최대로 요청)
  ]);
}

/// 소유자 정보와 잔여 PIN 입력 횟수를 요청하는 APDU 명령어를 생성합니다.
/// 애플릿 코드의 `getCardInfo` 함수에 해당하며, C-DATA 없이 Le 필드만 포함합니다.
Uint8List generateGetCardInfoCommand() {
  return Uint8List.fromList([
    0xFF, // CLA
    0xA0, // INS_GET_CARD_INFO
    0x00, // P1
    0x00, // P2
    0x00, // Le (카드에서 보낼 수 있는 최대 길이의 응답을 요청)
  ]);
}

/// 애플릿을 선택하는 APDU 명령어를 생성합니다.
Uint8List generateSelectAppletCommand() {
  return Uint8List.fromList([
    0x00, // CLA
    0xA4, // INS_SELECT
    0x04, // P1 (애플릿 선택)
    0x00, // P2 (전체 선택)
    0x07, // Lc (데이터 길이)
    0x4F, 0x6E, 0x65, 0x43, 0x61, 0x72, 0x64 // AID (애플릿 ID)
  ]);
}