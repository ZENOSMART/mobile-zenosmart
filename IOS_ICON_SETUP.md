# iOS Uygulama Simgesi Kurulum Rehberi

## Sorun

iOS'ta uygulama simgesi gözükmüyor.

## Çözüm Adımları

### 1. Flutter Launcher Icons Komutunu Çalıştırın

Mac Terminal'de proje klasöründe:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

veya yeni Flutter sürümlerinde:

```bash
dart run flutter_launcher_icons
```

Bu komut `assets/icons/zenosmart-connect-favikon.png` dosyasından tüm iOS simge boyutlarını otomatik oluşturur.

### 2. Xcode'da Kontrol Edin

1. Xcode'da projeyi açın:

```bash
open ios/Runner.xcworkspace
```

2. Sol panelde `Runner` > `Assets.xcassets` > `AppIcon` klasörüne gidin

3. Tüm simge slotlarının dolu olduğundan emin olun:
   - iPhone: 20x20, 29x29, 40x40, 60x60 (1x, 2x, 3x)
   - iPad: 20x20, 29x29, 40x40, 76x76 (1x, 2x)
   - App Store: 1024x1024

### 3. Xcode'da Clean Build

Xcode'da:

1. `Product` > `Clean Build Folder` (Shift + Cmd + K)
2. `Product` > `Build` (Cmd + B)

### 4. Simulator/Cihazda Test

```bash
# Simulator'ı temizle ve yeniden yükle
flutter clean
flutter pub get
flutter run -d ios
```

### 5. Eğer Hala Gözükmüyorsa

#### Seçenek A: Xcode'dan Manuel Olarak

1. Xcode'da `Runner` > `Assets.xcassets` > `AppIcon` açın
2. Her simge slotuna manuel olarak simge sürükleyin
3. 1024x1024 boyutunda bir PNG dosyası hazırlayın
4. App Store simgesi için `Icon-App-1024x1024@1x.png` dosyasını kontrol edin

#### Seçenek B: Simge Dosyasını Kontrol Edin

Simge dosyası en az 1024x1024 piksel olmalı:

```bash
# Simge dosyasını kontrol et
file assets/icons/zenosmart-connect-favikon.png
```

Eğer simge çok küçükse, daha büyük bir versiyon oluşturun.

### 6. Info.plist Kontrolü

`ios/Runner/Info.plist` dosyasında simge ile ilgili özel bir ayar yoksa sorun yok. Xcode otomatik olarak `Assets.xcassets/AppIcon` kullanır.

## Önemli Notlar

- iOS simgeleri **PNG formatında** olmalı (JPG değil)
- Simgeler **transparan olmamalı** (alpha channel olmamalı)
- 1024x1024 App Store simgesi **mutlaka** olmalı
- Simgeler **yuvarlatılmış köşeler içermemeli** (iOS otomatik yuvarlatır)

## Hızlı Test

```bash
# Tüm adımları tek seferde
flutter clean
flutter pub get
dart run flutter_launcher_icons
cd ios
pod install
cd ..
flutter run -d ios
```
