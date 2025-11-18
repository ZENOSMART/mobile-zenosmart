import '../repositories/device_repository.dart';
import '../repositories/device_detail_repository.dart';
import '../repositories/device_type_models_repository.dart';
import '../repositories/device_channel_templates_repository.dart';
import '../product-service/product_api_service.dart';
import '../models/device_type.dart';
import 'bluetooth_service.dart';
import '../helpers/device_settings_helper.dart';
import 'package:flutter/foundation.dart';

class DeviceSetupService {
  final DeviceRepository _deviceRepo;
  final DeviceDetailRepository _detailRepo;
  final DeviceTypeModelsRepository _typeModelRepo;
  final DeviceChannelTemplatesRepository _channelRepo;
  final ProductApiService _apiService;
  final BluetoothService _bluetoothService;

  const DeviceSetupService({
    DeviceRepository deviceRepo = const DeviceRepository(),
    DeviceDetailRepository detailRepo = const DeviceDetailRepository(),
    DeviceTypeModelsRepository typeModelRepo =
        const DeviceTypeModelsRepository(),
    DeviceChannelTemplatesRepository channelRepo =
        const DeviceChannelTemplatesRepository(),
    ProductApiService apiService = const ProductApiService(),
    BluetoothService bluetoothService = const BluetoothService(),
  }) : _deviceRepo = deviceRepo,
       _detailRepo = detailRepo,
       _typeModelRepo = typeModelRepo,
       _channelRepo = channelRepo,
       _apiService = apiService,
       _bluetoothService = bluetoothService;

  Future<String?> ensureDeviceTypeModel(String orderCode) async {
    try {
      final localTypeModel = await _typeModelRepo.getByOrderCode(orderCode);
      if (localTypeModel != null) {
        // Localde model varsa, kanal şablonlarını da kontrol edelim
        final channelId = localTypeModel['id'] as String?;
        if (channelId != null) {
          final channels = await _channelRepo.getByDeviceTypeModelsId(
            channelId,
          );
          // Eğer kanal şablonları yoksa, yeniden almayı deneyelim
          if (channels == null || channels.isEmpty) {
            await _fetchAndSaveChannelTemplatesForModel(channelId, orderCode);
          }
        }
        return channelId;
      }

      // Yeni model alımı için transactional yaklaşım
      String? deviceTypeModelId;
      bool channelsSaved = false;

      try {
        final typeModelResponse = await _apiService
            .getByDeviceTypeModelByOrderCode(orderCode: orderCode);

        // API'den gelen yanıtı kontrol et
        if (!typeModelResponse.success) {
          throw Exception(
            'API hatası: ${typeModelResponse.message ?? 'Bilinmeyen hata'}',
          );
        }

        if (typeModelResponse.data == null ||
            typeModelResponse.data!.content.isEmpty) {
          throw Exception('Order Code için model bulunamadı');
        }

        final remoteModel = typeModelResponse.data!.content.first;

        deviceTypeModelId = await _typeModelRepo.upsert(
          mainId: remoteModel.id,
          deviceTypeId: remoteModel.deviceTypeDto?.id ?? '',
          classType: remoteModel.classType,
          orderCode: remoteModel.orderCode,
        );

        // Kanal şablonlarını al ve kaydet
        await _fetchAndSaveChannelTemplates(
          remoteModelId: remoteModel.id,
          deviceTypeModelId: deviceTypeModelId,
        );

        channelsSaved = true;
        return deviceTypeModelId;
      } catch (e) {
        // Hata oluşursa ve model kaydedildiyse ama kanal şablonları alınamadıysa
        // modeli geri al (sil)
        if (deviceTypeModelId != null && !channelsSaved) {
          try {
            await _typeModelRepo.deleteById(deviceTypeModelId);
          } catch (deleteError) {
            // Silme hatası loglanabilir ama asıl hata önemli
            debugPrint('Model silme hatası: $deleteError');
          }
        }

        // Asıl hatayı yeniden fırlat
        rethrow;
      }
    } catch (e) {
      // Detaylı hata mesajı oluştur
      if (e is Exception) {
        rethrow; // Zaten özel bir hata mesajı varsa olduğu gibi fırlat
      } else {
        // Beklenmeyen hata durumunda daha açıklayıcı mesaj
        throw Exception(
          'Cihaz tipi modeli alınırken hata oluştu: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _fetchAndSaveChannelTemplatesForModel(
    String deviceTypeModelId,
    String orderCode,
  ) async {
    try {
      // Önce orderCode ile modeli al
      final typeModelResponse = await _apiService
          .getByDeviceTypeModelByOrderCode(orderCode: orderCode);

      if (typeModelResponse.success &&
          typeModelResponse.data != null &&
          typeModelResponse.data!.content.isNotEmpty) {
        final remoteModel = typeModelResponse.data!.content.first;

        await _fetchAndSaveChannelTemplates(
          remoteModelId: remoteModel.id,
          deviceTypeModelId: deviceTypeModelId,
        );
      }
    } catch (e) {
      // Kanal şablonlarının alınmasında hata oluşursa kritik hata olarak ele al
      throw Exception(
        'Kanal şablonları alınırken kritik hata oluştu: ${e.toString()}',
      );
    }
  }

  Future<void> _fetchAndSaveChannelTemplates({
    required String remoteModelId,
    required String deviceTypeModelId,
  }) async {
    try {
      final channelResponse = await _apiService
          .getByDeviceChannelTemplatesByTypeModelId(
            deviceTypeModelId: remoteModelId,
          );

      // API'den gelen yanıtı kontrol et
      if (!channelResponse.success) {
        // Kanal şablonlarının alınamaması kritik bir hata
        throw Exception(
          'Kanal şablonları alınamadı: ${channelResponse.message ?? 'Bilinmeyen hata'}',
        );
      }

      if (channelResponse.data != null) {
        for (final channel in channelResponse.data!.content) {
          await _channelRepo.insert(
            mainId: channel.id,
            channelCode: channel.channelCode,
            channelType: channel.channelType ?? '',
            dataType: channel.dataType ?? '',
            dataLimitMin: channel.dataLimitMin,
            dataLimitMax: channel.dataLimitMax,
            dataByteLenght: channel.dataByteLength,
            mqttPackageOrder: channel.mqttPackageOrder,
            hasSubChannel: channel.hasSubChannel ?? false,
            formula: channel.formula != null
                ? Map<String, Object>.from(channel.formula!)
                : null,
            deviceTypeModelsId: deviceTypeModelId,
            enName: channel.enName,
            trName: channel.trName,
            frName: channel.frName,
            arName: channel.arName,
            esName: channel.esName,
          );
        }
      } else {
        // Kanal verisi boşsa da kritik hata olarak ele al
        throw Exception('Kanal şablonları boş döndü');
      }
    } catch (e) {
      // Kanal şablonlarının alınmasında hata oluşursa kritik hata olarak ele al
      throw Exception(
        'Kanal şablonları alınırken kritik hata oluştu: ${e.toString()}',
      );
    }
  }

  Future<void> setupDevice({
    required String uniqueKey,
    required String name,
    required String orderCode,
    required String devEui,
    required String joinEui,
    required double latitude,
    required double longitude,
    required String location,
    String? deviceType,
    String? deviceAddr,
    bool renameDevice = true,
  }) async {
    try {
      // Önce orderCode kontrolü yapılır
      final deviceTypeModelId = await ensureDeviceTypeModel(orderCode);

      final deviceTypeName =
          DeviceType.displayNameBySerial(deviceType) ?? deviceType;

      final deviceId = await _deviceRepo.upsert(
        uniqueData: uniqueKey,
        name: name.isEmpty ? null : name,
        deviceType: deviceType,
        deviceTypeName: deviceTypeName,
        deviceTypeId: deviceTypeModelId,
        orderCode: orderCode,
      );

      // Cihaz detaylarını veritabanına kaydet
      debugPrint('🔍 Cihaz UUID\'lerini alıyor...');
      final uuids = await _bluetoothService.setDeviceNameAndGetUuids(
        deviceId: uniqueKey,
        deviceName: name,
        renameDevice: renameDevice,
      );

      // UUID'lerin başarıyla alınıp alınmadığını kontrol et
      if (uuids.uartServiceUuid != null ||
          uuids.rxCharUuid != null ||
          uuids.txCharUuid != null) {
        debugPrint('📝 UUID\'ler veritabanına kaydediliyor...');
        debugPrint(
          '  UART Service: ${uuids.uartServiceUuid ?? "null (korunacak)"}',
        );
        debugPrint('  RX Char: ${uuids.rxCharUuid ?? "null (korunacak)"}');
        debugPrint('  TX Char: ${uuids.txCharUuid ?? "null (korunacak)"}');
      } else {
        debugPrint(
          '⚠️ Uyarı: Hiçbir UUID bulunamadı, mevcut UUID\'ler korunacak',
        );
      }

      await _detailRepo.upsert(
        deviceId: deviceId,
        uartServiceUuid: uuids.uartServiceUuid,
        rxCharUuid: uuids.rxCharUuid,
        txCharUuid: uuids.txCharUuid,
      );

      debugPrint('✅ Cihaz detayları başarıyla kaydedildi');
    } catch (e) {
      // Detaylı hata mesajı oluştur
      if (e is Exception) {
        rethrow; // Zaten özel bir hata mesajı varsa olduğu gibi fırlat
      } else {
        // Beklenmeyen hata durumunda daha açıklayıcı mesaj
        throw Exception(
          'Cihaz kurulumu sırasında hata oluştu: ${e.toString()}',
        );
      }
    }
  }

  /// Cihaza identity settings verisi gönderir (3 kez tekrarlar)
  Future<bool> sendIdentitySettings({
    required String uniqueKey,
    required String devEui,
    required String joinEui,
    String? deviceAddr,
    Function(int attempt)? onAttempt,
  }) async {
    try {
      // DeviceAddr'ı parse et (4 byte olmalı)
      List<int>? deviceAddrBytes;
      if (deviceAddr != null && deviceAddr.isNotEmpty) {
        deviceAddrBytes = _hexStringToBytes(deviceAddr);
        if (deviceAddrBytes == null || deviceAddrBytes.length != 4) {
          debugPrint('❌ DeviceAddr geçersiz: $deviceAddr');
          return false;
        }
      }

      // Identity settings paketini oluştur
      final identityData = DeviceSettingsHelper.createDeviceCredentials(
        devEui: devEui,
        joinEui: joinEui,
        deviceAddr: deviceAddrBytes,
        counter: 1,
        groupId: 3,
      );

      debugPrint('📤 Identity settings paketi oluşturuldu');
      debugPrint('📤 DevEUI: $devEui, JoinEUI: $joinEui');
      debugPrint('📤 Packet length: ${identityData.length} bytes');

      // Identity settings verisini 3 kez gönder
      bool success = false;
      for (int i = 0; i < 3; i++) {
        // Deneme sayısını bildir
        onAttempt?.call(i + 1);

        debugPrint('📤 Identity settings gönderiliyor, deneme: ${i + 1}');
        success = await _bluetoothService.sendIdentitySettings(
          deviceId: uniqueKey,
          identityData: identityData,
        );

        if (success) {
          debugPrint(
            '✅ Identity settings başarıyla gönderildi, deneme: ${i + 1}',
          );
          break;
        } else {
          debugPrint('❌ Identity settings gönderilemedi, deneme: ${i + 1}');
          // Bekleme süresi ekle
          if (i < 2) {
            // Son denemeden sonra bekleme
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }

      return success;
    } catch (e) {
      debugPrint('❌ Identity settings gönderme hatası: $e');
      return false;
    }
  }

  /// Hex string'i byte listesine çevirir
  List<int>? _hexStringToBytes(String hexString) {
    try {
      final hex = hexString
          .replaceAll(RegExp(r'[^0-9a-fA-F]'), '')
          .toUpperCase();
      if (hex.length % 2 != 0) {
        return null;
      }
      final result = <int>[];
      for (var i = 0; i < hex.length; i += 2) {
        result.add(int.parse(hex.substring(i, i + 2), radix: 16));
      }
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Cihaza config settings verisi gönderir (3 kez tekrarlar)
  Future<bool> sendConfigDeploy({
    required String uniqueKey,
    required double latitude,
    required double longitude,
    Function(int attempt)? onAttempt, // Add callback for attempt tracking
  }) async {
    try {
      // Config settings paketini oluştur (yeni DeviceSettingsHelper kullan)
      final configData = DeviceSettingsHelper.createDeviceConfigSettings(
        latitude: latitude,
        longitude: longitude,
        counter: 1,
      );

      debugPrint('📤 Config settings paketi oluşturuldu');
      debugPrint('📤 Latitude: $latitude, Longitude: $longitude');
      debugPrint('📤 Packet length: ${configData.length} bytes');

      // Config settings verisini 3 kez gönder
      bool success = false;
      for (int i = 0; i < 3; i++) {
        // Deneme sayısını bildir
        onAttempt?.call(i + 1);

        debugPrint('📤 Config settings gönderiliyor, deneme: ${i + 1}');
        success = await _bluetoothService.sendConfigDeploy(
          deviceId: uniqueKey,
          configData: configData,
        );

        if (success) {
          debugPrint(
            '✅ Config settings başarıyla gönderildi, deneme: ${i + 1}',
          );
          break;
        } else {
          debugPrint('❌ Config settings gönderilemedi, deneme: ${i + 1}');
          // Bekleme süresi ekle
          if (i < 2) {
            // Son denemeden sonra bekleme
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }

      return success;
    } catch (e) {
      debugPrint('❌ Config settings gönderme hatası: $e');
      return false;
    }
  }
}
