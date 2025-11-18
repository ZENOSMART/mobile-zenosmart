import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'socket_manager.dart';
import 'update_client.dart';
import 'chunk_manager.dart';
import 'encryption_helper.dart';
import 'update_models.dart';

/// Bluetooth üzerinden firmware güncelleme yöneticisi
/// Tüm güncelleme sürecini yönetir
class UpdateManager {
  final SocketManager _socketManager = SocketManager();
  late final UpdateClient _updateClient;
  ChunkManager? _chunkManager;

  BluetoothCharacteristic? _rxCharacteristic;
  StreamSubscription<List<int>>? _notifySubscription;
  bool _shouldForwardChunks = false; // Chunk'ları göndermek için flag

  UpdateState _state = UpdateState.idle;
  UpdateInfo? _currentUpdateInfo;
  DeviceVersionInfo? _deviceVersionInfo;

  final _eventController = StreamController<UpdateEvent>.broadcast();
  Stream<UpdateEvent> get eventStream => _eventController.stream;

  UpdateState get state => _state;
  UpdateInfo? get currentUpdateInfo => _currentUpdateInfo;
  DeviceVersionInfo? get deviceVersionInfo => _deviceVersionInfo;

  UpdateManager() {
    _updateClient = UpdateClient(_socketManager);
  }

  /// Sunucuya bağlan
  Future<void> connectToServer({
    String host = 'update.zenosmart.com',
    int port = 80,
  }) async {
    try {
      _setState(UpdateState.connecting);
      debugPrint('[UpdateManager] Connecting to $host:$port...');

      await _socketManager.connect(host, port);

      // Sunucudan gelen veriyi dinle
      _socketManager.setOnData((data) async {
        debugPrint('[UpdateManager] 📥 Server data: ${data.length} bytes');
        
        if (_rxCharacteristic == null) {
          debugPrint('[UpdateManager] ⚠️ RX characteristic not set');
          return;
        }
        
        // Chunk'ları gönder (startUpdate sonrası)
        if (_shouldForwardChunks) {
          debugPrint('[UpdateManager] 📤 Sending chunk to device: ${data.length} bytes');
          await _writeToDevice(Uint8List.fromList(data));
          debugPrint('[UpdateManager] ✅ Chunk sent, waiting for next chunk request...');
          
          // Son chunk gönderildikten sonra tamamlanma kontrolü
          // NOT: Bu kontrol paket gönderildikten SONRA yapılmalı
          if (_chunkManager != null && _chunkManager!.isComplete) {
            debugPrint('[UpdateManager] ✅ Son chunk gönderildi, güncelleme tamamlandı!');
            _setState(UpdateState.completed);
            _emitCompleted('Firmware güncelleme başarılı oldu!');
            // Chunk forwarding'i durdur, artık chunk göndermeye gerek yok
            _shouldForwardChunks = false;
          }
        } else {
          debugPrint('[UpdateManager] ⏭️ Skipping data (chunk forwarding not enabled yet)');
        }
      });

      debugPrint('[UpdateManager] ✅ Connected to server');
    } catch (e) {
      _setState(UpdateState.failed);
      _emitError('Sunucu bağlantısı başarısız: $e');
      rethrow;
    }
  }

  /// BLE karakteristiğini ayarla
  /// NOT: Notification device_detail_page'de zaten açık, stream inject edilmeli
  Future<void> setupBleCharacteristic(
    BluetoothCharacteristic rxCharacteristic,
  ) async {
    _rxCharacteristic = rxCharacteristic;
    
    // MTU request - Büyük paketler için gerekli
    final device = rxCharacteristic.device;
    try {
      final mtu = await device.requestMtu(247);
      debugPrint('[UpdateManager] ✅ MTU requested: $mtu');
    } catch (e) {
      debugPrint('[UpdateManager] ⚠️ MTU request failed (may not be critical): $e');
    }
    
    debugPrint('[UpdateManager] ✅ RX characteristic set: ${rxCharacteristic.uuid}');
  }

  /// TX notification stream'ini bağla (device_detail_page'den)
  void attachNotificationStream(Stream<List<int>> notificationStream) {
    _notifySubscription?.cancel();
    _notifySubscription = notificationStream.listen(_handleDeviceData);
    debugPrint('[UpdateManager] ✅ Notification stream attached');
  }

  /// Manuel olarak cihaz datasını besle
  void feedDeviceData(List<int> data) {
    _handleDeviceData(data);
  }

  /// Cihazdan gelen veriyi işle
  void _handleDeviceData(List<int> data) {
    try {
      // RAW data logu (HEX formatında da göster)
      final hexString = data.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
      debugPrint('[UpdateManager] 📱 RX [RAW]: ${data.length} bytes: $data');
      debugPrint('[UpdateManager] 📱 RX [HEX]: $hexString');
      
      String str = '';
      try {
        str = String.fromCharCodes(data).trim();
        debugPrint('[UpdateManager] 📱 RX [TEXT]: $str');
      } catch (e) {
        // Binary data, string'e çevrilemez
        debugPrint('[UpdateManager] 📱 RX [BINARY]: Cannot decode to string');
        return;
      }

      // Versiyon bilgisi mi?
      if (str.contains('Project:') || str.contains('SW:') || str.contains('HW:')) {
        debugPrint('[UpdateManager] 🔍 Version data detected');
        _parseDeviceVersion(str);
        return;
      }

      // Chunk isteği mi?
      if (str.contains('ChunkSize')) {
        debugPrint('[UpdateManager] 🔍 Chunk request detected');
        
        if (_chunkManager == null) {
          debugPrint('[UpdateManager] ⚠️ ChunkManager is null!');
          return;
        }
        
        // İlerleme hesapla (parseChunkRequest partNum kontrolü yapar)
        final progress = _chunkManager!.parseChunkRequest(str);
        if (progress != null) {
          // Sadece geçerli chunk request'leri sunucuya gönder
          debugPrint('[UpdateManager] 📤 Forwarding chunk request to server: $str');
          _socketManager.send(str.codeUnits);
          debugPrint('[UpdateManager] ✅ Chunk request sent to server, waiting for response...');
          
          debugPrint('[UpdateManager] 📊 Progress: ${progress.progress * 100}% (part: ${progress.partNum + 1}/${progress.totalChunks})');
          _emitProgress(progress);

          // NOT: Tamamlanma kontrolünü burada yapmıyoruz
          // Çünkü paket henüz sunucudan gelmedi ve cihaza gönderilmedi
          // Tamamlanma kontrolü _socketManager.setOnData içinde, paket gönderildikten sonra yapılacak
        } else {
          debugPrint('[UpdateManager] ⚠️ Chunk request geçersiz (partNum maksimum değeri aşıyor), sunucuya gönderilmedi');
        }
      } else {
        debugPrint('[UpdateManager] ℹ️ Unknown message from device: $str');
      }
    } catch (e) {
      debugPrint('[UpdateManager] ❌ Handle error: $e');
    }
  }

  /// Cihazdan gelen versiyon bilgisini parse et
  /// Örnek: "Project:LORA_MODULE SW:1.2.3 HW:V1.0"
  void _parseDeviceVersion(String data) {
    try {
      final swMatch = RegExp(r'SW:([^\s]+)').firstMatch(data);
      final hwMatch = RegExp(r'HW:([^\s]+)').firstMatch(data);
      final projMatch = RegExp(r'Project:([^\s]+)').firstMatch(data);

      _deviceVersionInfo = DeviceVersionInfo(
        swVersion: swMatch?.group(1),
        hwVersion: hwMatch?.group(1),
        project: projMatch?.group(1),
      );

      debugPrint('[UpdateManager] ✅ Device version: $_deviceVersionInfo');
      _eventController.add(UpdateStateChanged(UpdateState.idle));
    } catch (e) {
      debugPrint('[UpdateManager] ❌ Parse version error: $e');
    }
  }

  /// Sunucudan firmware bilgisi al
  /// FileState cihaza gönderilmez, sadece bilgi alınır
  Future<UpdateInfo?> fetchFirmwareInfo({
    required String project,
    required String hwVersion,
  }) async {
    try {
      _setState(UpdateState.fetchingInfo);
      debugPrint('[UpdateManager] Fetching firmware info...');

      final info = await _updateClient.fetchLatestFirmware(
        project: project,
        hwVersion: hwVersion,
      );

      if (info != null) {
        _currentUpdateInfo = info;
        _chunkManager = ChunkManager(info.fileSize);
        _setState(UpdateState.ready);
        debugPrint('[UpdateManager] ✅ Firmware info received (FileState will be sent when startUpdate is called)');
      } else {
        _setState(UpdateState.idle);
        _emitError('Sunucudan firmware bilgisi alınamadı');
      }

      return info;
    } catch (e) {
      _setState(UpdateState.failed);
      _emitError('Firmware bilgisi alma hatası: $e');
      return null;
    }
  }

  /// Sunucu cevabını cihaza gönder (FileState)
  Future<void> sendServerResponseToDevice() async {
    if (_currentUpdateInfo == null) {
      _emitError('Önce sunucudan firmware bilgisi alınmalı');
      return;
    }

    if (_rxCharacteristic == null) {
      _emitError('BLE karakteristiği ayarlanmamış');
      return;
    }

    try {
      debugPrint('[UpdateManager] Sending server response to device...');
      await _writeToDevice(_currentUpdateInfo!.rawEncryptedResponse);
      
      // FileState gönderildikten SONRA updating durumuna geç
      _setState(UpdateState.updating);
      debugPrint('[UpdateManager] ✅ Server response sent, now waiting for chunks...');
    } catch (e) {
      _setState(UpdateState.failed);
      _emitError('Sunucu cevabı gönderilemedi: $e');
      rethrow;
    }
  }

  /// Cihazdan versiyon bilgisi iste
  Future<void> requestDeviceVersion() async {
    if (_rxCharacteristic == null) {
      _emitError('BLE karakteristiği ayarlanmamış');
      return;
    }

    try {
      debugPrint('[UpdateManager] Requesting device version...');

      // "GET_VERSION" komutunu şifrele ve gönder
      const command = 'GET_VERSION\n';
      final plainBytes = Uint8List.fromList(utf8.encode(command));
      final encrypted = EncryptionHelper.xorEncrypt(plainBytes);

      await _writeToDevice(encrypted);
      debugPrint('[UpdateManager] ✅ Version request sent (encrypted)');
    } catch (e) {
      _emitError('Versiyon bilgisi istenemedi: $e');
      rethrow;
    }
  }

  /// Güncellemeyi başlat (FileState + START_UPDATE komutu)
  /// Önce FileState gönderilir, sonra START_UPDATE, sonra chunk modu açılır
  Future<void> startUpdate() async {
    if (_currentUpdateInfo == null || !_currentUpdateInfo!.isUpdateAvailable) {
      _emitError('Güncelleme mevcut değil');
      return;
    }

    if (_rxCharacteristic == null) {
      _emitError('BLE karakteristiği ayarlanmamış');
      return;
    }

    try {
      _setState(UpdateState.updating);
      
      // Önce FileState'i cihaza gönder
      debugPrint('[UpdateManager] Sending FileState to device...');
      await _writeToDevice(_currentUpdateInfo!.rawEncryptedResponse);
      debugPrint('[UpdateManager] ✅ FileState sent to device');
      
      // Chunk gönderme modunu aç ve reset
      _shouldForwardChunks = true;
      _chunkManager?.reset();
      debugPrint('[UpdateManager] ✅ Chunk forwarding enabled, ChunkManager reset');

      // Sonra START_UPDATE gönder
      debugPrint('[UpdateManager] Sending START_UPDATE...');
      const command = 'START_UPDATE';
      final encrypted = EncryptionHelper.encryptString(command);
      
      await _writeToDevice(encrypted);
      debugPrint('[UpdateManager] ✅ START_UPDATE sent');
    } catch (e) {
      _setState(UpdateState.failed);
      _emitError('Güncelleme başlatılamadı: $e');
      rethrow;
    }
  }

  /// Cihaza veri yaz
  Future<void> _writeToDevice(Uint8List data) async {
    if (_rxCharacteristic == null) return;

    try {
      await _rxCharacteristic!.write(
        data,
        withoutResponse: _rxCharacteristic!.properties.writeWithoutResponse,
      );
      debugPrint('[UpdateManager] 📤 BLE TX: ${data.length} bytes');
    } catch (e) {
      debugPrint('[UpdateManager] ❌ Write error: $e');
      rethrow;
    }
  }

  /// Durumu değiştir
  void _setState(UpdateState newState) {
    _state = newState;
    _eventController.add(UpdateStateChanged(newState));
    debugPrint('[UpdateManager] State: $newState');
  }

  /// İlerleme bildir
  void _emitProgress(ChunkProgress progress) {
    _eventController.add(UpdateProgressChanged(progress));
  }

  /// Hata bildir
  void _emitError(String message) {
    _eventController.add(UpdateError(message));
    debugPrint('[UpdateManager] ❌ Error: $message');
  }

  /// Tamamlanma bildir
  void _emitCompleted(String message) {
    _eventController.add(UpdateCompleted(message));
    debugPrint('[UpdateManager] ✅ Completed: $message');
  }

  /// Kaynakları temizle
  Future<void> dispose() async {
    debugPrint('[UpdateManager] 🧹 Disposing...');
    await _notifySubscription?.cancel();
    debugPrint('[UpdateManager] ✅ Notification subscription cancelled');
    await _socketManager.dispose();
    debugPrint('[UpdateManager] ✅ Socket manager disposed');
    await _eventController.close();
    _rxCharacteristic = null;
    _chunkManager = null;
    _currentUpdateInfo = null;
    debugPrint('[UpdateManager] ✅ Disposed completely');
  }

  /// Bağlantıyı kapat
  void disconnect() {
    _socketManager.disconnect();
    _setState(UpdateState.idle);
  }
}
