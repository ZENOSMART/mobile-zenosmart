import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'socket_manager.dart';
import 'encryption_helper.dart';
import 'update_models.dart';

/// Firmware güncelleme client sınıfı
/// Sunucudan firmware bilgisi alır
class UpdateClient {
  final SocketManager _socketManager;
  static const Duration _timeout = Duration(seconds: 5);

  UpdateClient(this._socketManager);

  /// Sunucudan en son firmware bilgisini al
  Future<UpdateInfo?> fetchLatestFirmware({
    required String project,
    required String hwVersion,
  }) async {
    try {
      debugPrint('[UpdateClient] Fetching firmware info...');
      debugPrint('[UpdateClient] Project: $project, HW: $hwVersion');

      // JSON payload hazırla
      final payload = jsonEncode({'project': project, 'hw_version': hwVersion});

      // İsteği gönder
      final requestBytes = utf8.encode('$payload\n');
      debugPrint('[UpdateClient] 📤 Request: $payload');

      // Cevap bekle
      final rawResponse = await _socketManager.sendAndWaitResponse(
        requestBytes,
        timeout: _timeout,
      );

      if (rawResponse.isEmpty) {
        debugPrint('[UpdateClient] ❌ No response from server');
        return null;
      }

      debugPrint(
        '[UpdateClient] 📥 Response: ${rawResponse.length} bytes (encrypted)',
      );

      // Şifreli cevabı sakla (STM32'ye gönderilecek)
      final encryptedBytes = Uint8List.fromList(rawResponse);

      // Deşifre et (bilgi almak için)
      final decrypted = EncryptionHelper.xorDecrypt(encryptedBytes);
      final reply = utf8.decode(decrypted, allowMalformed: true);
      debugPrint('[UpdateClient] 📝 Decrypted: $reply');

      // Parse et
      final version = _extractVersion(reply);
      final fileSize = _extractInt(reply, 'FileSize:');
      final fileState = _extractInt(reply, 'FileState:');

      final info = UpdateInfo(
        version: version,
        fileSize: fileSize,
        fileState: fileState,
        rawEncryptedResponse: encryptedBytes,
      );

      debugPrint('[UpdateClient] ✅ $info');
      return info;
    } catch (e) {
      debugPrint('[UpdateClient] ❌ Error: $e');
      return null;
    }
  }

  /// Version bilgisini çıkar
  /// Örnek: "Version: 1.2.3" -> "1.2.3"
  String? _extractVersion(String text) {
    final match = RegExp(r'Version:\s*([\d.]+)').firstMatch(text);
    return match?.group(1);
  }

  /// Integer değer çıkar
  /// Örnek: "FileSize: 50000" -> 50000
  int _extractInt(String text, String tag) {
    final idx = text.indexOf(tag);
    if (idx == -1) return 0;

    final numStr = RegExp(r'\d+').stringMatch(text.substring(idx + tag.length));

    return int.tryParse(numStr ?? '') ?? 0;
  }
}
