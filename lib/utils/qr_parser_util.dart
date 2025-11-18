class QrParserUtil {
  /// QR kod metnini parse eder ve anahtar-değer çiftleri döndürür
  static Map<String, String> parse(String raw) {
    final text = raw.replaceAll('\r', '\n');
    final lines = text.split(RegExp('[\n,]'));
    final map = <String, String>{};
    
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split(':');
      if (parts.length < 2) continue;
      
      final key = parts[0].trim().toLowerCase();
      final value = parts.sublist(1).join(':').trim();
      
      if (key.isEmpty || value.isEmpty) continue;
      map[key] = value;
    }
    
    return map;
  }

  /// QR kod haritasından DevEUI değerini çıkarır
  static String? extractDevEui(Map<String, String> qrData) {
    return qrData['deveui'] ?? qrData['dev eui'] ?? qrData['dev_eui'];
  }

  /// QR kod haritasından JoinEUI değerini çıkarır
  static String? extractJoinEui(Map<String, String> qrData) {
    return qrData['joineui'] ?? qrData['join eui'] ?? qrData['join_eui'];
  }

  /// QR kod haritasından DeviceAddr değerini çıkarır
  static String? extractDeviceAddr(Map<String, String> qrData) {
    return qrData['devaddr'] ??
        qrData['dev addr'] ??
        qrData['dev_addr'] ??
        qrData['deviceaddr'] ??
        qrData['device addr'];
  }

  /// QR kod haritasından OrderCode değerini çıkarır
  static String? extractOrderCode(Map<String, String> qrData) {
    return qrData['ordercode'] ?? qrData['order code'] ?? qrData['order_code'];
  }
}

















