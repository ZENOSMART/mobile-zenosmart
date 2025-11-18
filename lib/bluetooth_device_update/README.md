# Bluetooth Device Update Module

Bluetooth üzerinden cihaz firmware güncelleme modülü.

## 📦 İçerik

- **UpdateManager**: Ana güncelleme yöneticisi
- **SocketManager**: TCP sunucu bağlantı yöneticisi
- **UpdateClient**: Sunucudan firmware bilgisi alma
- **ChunkManager**: Chunk transfer yönetimi
- **EncryptionHelper**: XOR şifreleme
- **UpdateModels**: Veri modelleri

## 🚀 Kullanım

### 1. Import

```dart
import 'package:flutter_application_1/bluetooth_device_update/bluetooth_device_update.dart';
```

### 2. UpdateManager Oluştur

```dart
final updateManager = UpdateManager();
```

### 3. Event Stream'i Dinle

```dart
updateManager.eventStream.listen((event) {
  if (event is UpdateStateChanged) {
    print('State: ${event.state}');
  } else if (event is UpdateProgressChanged) {
    print('Progress: ${event.progress.progress * 100}%');
  } else if (event is UpdateError) {
    print('Error: ${event.message}');
  } else if (event is UpdateCompleted) {
    print('Completed: ${event.message}');
  }
});
```

### 4. Sunucuya Bağlan

```dart
await updateManager.connectToServer(
  host: 'update.zenosmart.com',
  port: 80,
);
```

### 5. BLE Karakteristiğini Ayarla

```dart
// BLE bağlantısı kurduktan sonra
await updateManager.setupBleCharacteristic(rxCharacteristic);
```

### 6. Firmware Bilgisi Al

```dart
final info = await updateManager.fetchFirmwareInfo(
  project: 'LORA_MODULE',
  hwVersion: 'V1.0',
);

if (info != null && info.isUpdateAvailable) {
  print('Yeni versiyon mevcut: ${info.version}');
  print('Dosya boyutu: ${info.fileSize} bytes');
}
```

### 7. Sunucu Cevabını Cihaza Gönder

```dart
await updateManager.sendServerResponseToDevice();
```

### 8. Güncellemeyi Başlat

```dart
await updateManager.startUpdate();
```

### 9. Temizlik

```dart
@override
void dispose() {
  updateManager.dispose();
  super.dispose();
}
```

## 📊 Güncelleme Akışı

```
1. connectToServer()
2. setupBleCharacteristic()
3. fetchFirmwareInfo()
4. sendServerResponseToDevice()
5. startUpdate()
6. [Otomatik chunk transfer]
7. [İlerleme event'leri]
8. [Tamamlanma event'i]
```

## 🔐 Şifreleme

Tüm veriler XOR algoritması ile şifrelenir:

- Key: `"simple_key"`
- Hem sunucudan gelen hem cihaza gönderilen veriler şifreli
- STM32 kendi içinde deşifre eder

## 📝 Event Türleri

- **UpdateStateChanged**: Durum değişikliği
- **UpdateProgressChanged**: İlerleme güncelleme
- **UpdateError**: Hata mesajı
- **UpdateCompleted**: Tamamlanma mesajı

## ⚡ Durum Değerleri

```dart
enum UpdateState {
  idle,        // Beklemede
  connecting,  // Sunucuya bağlanıyor
  fetchingInfo,// Bilgi alınıyor
  ready,       // Hazır
  updating,    // Güncelliyor
  completed,   // Tamamlandı
  failed,      // Başarısız
}
```

## 🎯 Önemli Notlar

1. BLE bağlantısı güncelleme sırasında açık kalmalı
2. Sunucu bağlantısı otomatik yeniden bağlanır
3. Chunk transfer STM32 tarafından kontrol edilir
4. Flutter app sadece köprü görevi görür
5. İlerleme bilgisi chunk sayısına göre hesaplanır

## 🔧 Hata Yönetimi

Tüm hatalar `UpdateError` event'i olarak bildirilir:

```dart
updateManager.eventStream.listen((event) {
  if (event is UpdateError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(event.message)),
    );
  }
});
```
