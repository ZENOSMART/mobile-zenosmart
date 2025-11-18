import 'dart:typed_data';

/// XOR tabanlı şifreleme helper sınıfı
class EncryptionHelper {
  static const String _defaultKey = 'simple_key';

  /// XOR ile şifreleme (hem şifreleme hem deşifreleme aynı)
  static Uint8List xorEncrypt(Uint8List data, [String? key]) {
    final keyBytes = Uint8List.fromList((key ?? _defaultKey).codeUnits);
    final result = Uint8List(data.length);

    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ keyBytes[i % keyBytes.length];
    }

    return result;
  }

  /// XOR ile deşifreleme (şifreleme ile aynı)
  static Uint8List xorDecrypt(Uint8List data, [String? key]) {
    return xorEncrypt(data, key);
  }

  /// String'i şifrele
  static Uint8List encryptString(String text, [String? key]) {
    return xorEncrypt(Uint8List.fromList(text.codeUnits), key);
  }

  /// Şifrelenmiş veriyi string'e çevir
  static String decryptToString(Uint8List data, [String? key]) {
    final decrypted = xorDecrypt(data, key);
    return String.fromCharCodes(decrypted);
  }
}
