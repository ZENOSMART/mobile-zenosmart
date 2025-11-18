import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothService {
  const BluetoothService();

  static const String _uartServicePrefix = '6e400001-b5a3-f393-e0a9-e50e24dcca';
  static const String _rxCharPrefix = '6e400002-b5a3-f393-e0a9-e50e24dcca';
  static const String _txCharPrefix = '6e400003-b5a3-f393-e0a9-e50e24dcca';

  /// Cihaza Bluetooth ile bağlanıp UUID'leri döndürür
  Future<BluetoothConnectionResult> setDeviceNameAndGetUuids({
    required String deviceId,
    required String deviceName,
    bool renameDevice = true,
  }) async {
    String? foundUartServiceUuid;
    String? foundRxCharUuid;
    String? foundTxCharUuid;

    try {
      final device = BluetoothDevice.fromId(deviceId);

      // Cihaza bağlan
      await device.connect(timeout: const Duration(seconds: 10));

      // Servisleri keşfet
      final services = await device.discoverServices();

      debugPrint('=== TÜM SERVİSLER ===');
      for (var service in services) {
        debugPrint('Servis: ${service.uuid}');
        for (var char in service.characteristics) {
          debugPrint('  - Karakteristik: ${char.uuid}');
          debugPrint(
            '    Properties: read=${char.properties.read}, write=${char.properties.write}, writeWithoutResponse=${char.properties.writeWithoutResponse}',
          );
        }
      }

      // UART servisini ve karakteristiklerini bul
      for (var service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();

        if (serviceUuid.startsWith(_uartServicePrefix)) {
          foundUartServiceUuid = serviceUuid;
          debugPrint('✓ UART servisi bulundu: $serviceUuid');

          for (var char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();

            // RX karakteristiği
            if (charUuid.startsWith(_rxCharPrefix)) {
              foundRxCharUuid = charUuid;
              debugPrint('✓ RX karakteristik bulundu: $charUuid');
            }
            // TX karakteristiği
            else if (charUuid.startsWith(_txCharPrefix)) {
              foundTxCharUuid = charUuid;
              debugPrint('✓ TX karakteristik bulundu: $charUuid');
            }
          }
          break;
        }
      }

      // Bağlantıyı kes
      await device.disconnect();

      // UUID'lerin bulunup bulunmadığını kontrol et
      if (foundUartServiceUuid == null ||
          foundRxCharUuid == null ||
          foundTxCharUuid == null) {
        debugPrint('⚠️ Uyarı: Bazı UUID\'ler bulunamadı:');
        debugPrint('  UART Service: ${foundUartServiceUuid ?? "BULUNAMADI"}');
        debugPrint('  RX Char: ${foundRxCharUuid ?? "BULUNAMADI"}');
        debugPrint('  TX Char: ${foundTxCharUuid ?? "BULUNAMADI"}');
      } else {
        debugPrint('✓ Tüm UUID\'ler başarıyla bulundu');
      }
    } catch (e) {
      debugPrint('❌ Bluetooth bağlantı hatası: $e');
      // Hata durumunda da mevcut UUID'leri korumak için null dönüyoruz
      // Böylece mevcut UUID'ler veritabanında korunur
    }

    return BluetoothConnectionResult(
      uartServiceUuid: foundUartServiceUuid,
      rxCharUuid: foundRxCharUuid,
      txCharUuid: foundTxCharUuid,
    );
  }

  /// Cihaza identity settings verisi gönderir
  Future<bool> sendIdentitySettings({
    required String deviceId,
    required List<int> identityData,
  }) async {
    try {
      final device = BluetoothDevice.fromId(deviceId);

      // Cihaza bağlan
      await device.connect(timeout: const Duration(seconds: 10));

      // Servisleri keşfet
      final services = await device.discoverServices();

      BluetoothCharacteristic? targetChar;

      // UART servisini ve karakteristiklerini bul
      for (var service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();

        if (serviceUuid.startsWith(_uartServicePrefix)) {
          for (var char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();

            // RX karakteristiği
            if (charUuid.startsWith(_rxCharPrefix)) {
              if (char.properties.write ||
                  char.properties.writeWithoutResponse) {
                targetChar = char;
                debugPrint('✓ RX karakteristik bulundu: $charUuid');
              }
            }
          }
          break;
        }
      }

      // Identity settings verisini gönder
      if (targetChar != null) {
        debugPrint(
          'Identity settings verisi gönderiliyor, uzunluk: ${identityData.length}',
        );

        if (targetChar.properties.writeWithoutResponse) {
          await targetChar.write(identityData, withoutResponse: true);
        } else {
          await targetChar.write(identityData, withoutResponse: false);
        }

        debugPrint('✓ Identity settings verisi gönderildi');
        await Future.delayed(const Duration(milliseconds: 500));

        // Bağlantıyı kes
        await device.disconnect();
        return true;
      } else {
        debugPrint('RX karakteristik bulunamadı');
        // Bağlantıyı kes
        await device.disconnect();
        return false;
      }
    } catch (e) {
      debugPrint('Identity settings gönderme hatası: $e');
      return false;
    }
  }

  /// Cihaza config deploy verisi gönderir
  Future<bool> sendConfigDeploy({
    required String deviceId,
    required List<int> configData,
  }) async {
    try {
      final device = BluetoothDevice.fromId(deviceId);

      // Cihaza bağlan
      await device.connect(timeout: const Duration(seconds: 10));

      // Servisleri keşfet
      final services = await device.discoverServices();

      BluetoothCharacteristic? targetChar;

      // UART servisini ve karakteristiklerini bul
      for (var service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();

        if (serviceUuid.startsWith(_uartServicePrefix)) {
          for (var char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();

            // RX karakteristiği
            if (charUuid.startsWith(_rxCharPrefix)) {
              if (char.properties.write ||
                  char.properties.writeWithoutResponse) {
                targetChar = char;
                debugPrint('✓ RX karakteristik bulundu: $charUuid');
              }
            }
          }
          break;
        }
      }

      // Config deploy verisini gönder
      if (targetChar != null) {
        debugPrint(
          'Config deploy verisi gönderiliyor, uzunluk: ${configData.length}',
        );

        if (targetChar.properties.writeWithoutResponse) {
          await targetChar.write(configData, withoutResponse: true);
        } else {
          await targetChar.write(configData, withoutResponse: false);
        }

        debugPrint('✓ Config deploy verisi gönderildi');
        await Future.delayed(const Duration(milliseconds: 500));

        // Bağlantıyı kes
        await device.disconnect();
        return true;
      } else {
        debugPrint('RX karakteristik bulunamadı');
        // Bağlantıyı kes
        await device.disconnect();
        return false;
      }
    } catch (e) {
      debugPrint('Config deploy gönderme hatası: $e');
      return false;
    }
  }
}

class BluetoothConnectionResult {
  final String? uartServiceUuid;
  final String? rxCharUuid;
  final String? txCharUuid;

  BluetoothConnectionResult({
    this.uartServiceUuid,
    this.rxCharUuid,
    this.txCharUuid,
  });

  Map<String, String?> toMap() {
    return {
      'uartServiceUuid': uartServiceUuid,
      'rxCharUuid': rxCharUuid,
      'txCharUuid': txCharUuid,
    };
  }
}
