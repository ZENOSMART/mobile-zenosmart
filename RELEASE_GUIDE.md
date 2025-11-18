# Play Store Yayınlama Rehberi

## Versiyon Bilgisi

- **Version Name:** 1.0.1
- **Version Code:** 2
- **Değişiklikler:** Tek bağlantı optimizasyonu (add device işlemi artık tek bağlantıda yapılıyor)

## Ön Hazırlık

### 1. Keystore Kontrolü

Keystore dosyası mevcut: `android/upload-keystore.jks`
Key properties dosyası: `android/key.properties`

### 2. Flutter Temizleme ve Bağımlılıkları Güncelleme

```bash
flutter clean
flutter pub get
```

## Release Build Oluşturma

### Android App Bundle (AAB) - Önerilen Format

Play Store için AAB formatı önerilir (daha küçük dosya boyutu):

```bash
flutter build appbundle --release
```

Build dosyası şu konumda oluşacak:
`build/app/outputs/bundle/release/app-release.aab`

### Alternatif: APK Formatı

Eğer APK formatında build almak isterseniz:

```bash
flutter build apk --release
```

Build dosyası şu konumda oluşacak:
`build/app/outputs/flutter-apk/app-release.apk`

## Play Store Console'da Yayınlama

### 1. Google Play Console'a Giriş

- [Google Play Console](https://play.google.com/console) adresine gidin
- Uygulamanızı seçin

### 2. Yeni Sürüm Oluşturma

1. Sol menüden **"Production"** (veya **"Internal testing"** / **"Closed testing"** / **"Open testing"**) seçin
2. **"Create new release"** butonuna tıklayın

### 3. AAB/APK Yükleme

1. **"App bundles and APKs"** bölümüne gidin
2. **"Upload"** butonuna tıklayın
3. Oluşturduğunuz `app-release.aab` dosyasını seçin ve yükleyin

### 4. Sürüm Notları

**Türkçe:**

```
Yeni Özellikler:
• Cihaz ekleme işlemi optimize edildi - artık tek bağlantıda tamamlanıyor
• Daha hızlı ve verimli cihaz kurulumu

İyileştirmeler:
• Bluetooth bağlantı performansı artırıldı
• Güç tüketimi azaltıldı
```

**İngilizce:**

```
New Features:
• Device setup process optimized - now completes in a single connection
• Faster and more efficient device configuration

Improvements:
• Bluetooth connection performance improved
• Reduced power consumption
```

### 5. Sürümü Yayınlama

1. Sürüm notlarınızı ekleyin
2. **"Review release"** butonuna tıklayın
3. Tüm bilgileri kontrol edin
4. **"Start rollout to Production"** (veya test kanalınızı seçin) butonuna tıklayın

## Yayınlama Sonrası Kontroller

1. **Yayın Durumu:** Play Console'da sürümün durumunu kontrol edin
2. **İnceleme Süreci:** Google'ın incelemesi genellikle 1-3 gün sürer
3. **Yayınlanma:** İnceleme tamamlandıktan sonra uygulama otomatik olarak yayınlanır

## Notlar

- İlk yayınlama için Google'ın inceleme süreci daha uzun sürebilir
- Güncellemeler genellikle daha hızlı onaylanır
- AAB formatı kullanıldığında Google Play otomatik olarak cihaza uygun APK oluşturur
- Version code her yeni yayında artırılmalıdır (şu an: 2)

## Sorun Giderme

### Build Hatası Alırsanız

```bash
# Temizle ve yeniden dene
flutter clean
flutter pub get
flutter build appbundle --release
```

### Signing Hatası Alırsanız

- `android/key.properties` dosyasının doğru olduğundan emin olun
- `android/upload-keystore.jks` dosyasının mevcut olduğunu kontrol edin

### Version Code Hatası

- Play Store'da daha yüksek bir version code kullanılıyorsa, `pubspec.yaml`'daki build number'ı artırın
- Örnek: Eğer Play Store'da 5 varsa, `version: 1.0.1+6` yapın
