import 'dart:typed_data';

/// 헥스 문자열과 바이트 배열 간 변환을 위한 유틸리티 클래스
class HexUtils {
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
}
