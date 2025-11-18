# Mac'te Adım Adım Kurulum Rehberi

## ✅ Adım 1: Xcode Kurulumunu Doğrulama

Terminal'de şu komutu çalıştırın:

```bash
xcode-select --version
```

Eğer hata alırsanız, Xcode'u açın ve "Open Developer Tool" seçeneğini seçin. Sonra tekrar deneyin.

Xcode Command Line Tools'u yükleyin:

```bash
xcode-select --install
```

## ✅ Adım 2: CocoaPods Kurulumu

iOS bağımlılıkları için CocoaPods gereklidir:

```bash
sudo gem install cocoapods
```

Kurulumdan sonra doğrulayın:

```bash
pod --version
```

## ✅ Adım 3: Flutter SDK Kontrolü

Flutter'ın kurulu olup olmadığını kontrol edin:

```bash
flutter --version
```

Eğer Flutter yüklü değilse:

1. https://docs.flutter.dev/get-started/install/macos adresinden Flutter SDK'yı indirin
2. ZIP dosyasını açın ve bir klasöre çıkarın (örn: `~/development/flutter`)
3. PATH'e ekleyin. `~/.zshrc` veya `~/.bash_profile` dosyasına ekleyin:

```bash
export PATH="$PATH:$HOME/development/flutter/bin"
```

Sonra terminali yeniden başlatın veya:

```bash
source ~/.zshrc
```

## ✅ Adım 4: Flutter Doctor Kontrolü

Tüm gereksinimlerin yüklü olduğunu kontrol edin:

```bash
flutter doctor
```

**Beklenen çıktı:**

- ✅ Flutter (Channel stable, ...)
- ✅ Xcode - develop for iOS and macOS
- ✅ CocoaPods - CocoaPods version ...
- ⚠️ Android toolchain (opsiyonel, sadece Android derlemek istiyorsanız)

Eksik olanları `flutter doctor` komutunun önerdiği şekilde düzeltin.

## ✅ Adım 5: Projeyi İndirme

```bash
cd ~/Desktop  # veya istediğiniz bir klasör
git clone https://github.com/ZENOSMART/mobile-zenosmart.git
cd mobile-zenosmart
```

## ✅ Adım 6: Flutter Bağımlılıklarını Yükleme

```bash
flutter pub get
```

## ✅ Adım 7: iOS Bağımlılıklarını Yükleme

```bash
cd ios
pod install
cd ..
```

**Not:** İlk kez çalıştırıyorsanız biraz zaman alabilir.

## ✅ Adım 8: Projeyi Derleme

### iOS Simulator için:

Önce mevcut cihazları listeleyin:

```bash
flutter devices
```

iOS Simulator'ı başlatın (Xcode'dan veya):

```bash
open -a Simulator
```

Sonra projeyi çalıştırın:

```bash
flutter run -d ios
```

### Fiziksel iOS Cihaz için:

1. Xcode'da projeyi açın:

```bash
open ios/Runner.xcworkspace
```

2. Xcode'da:

   - Sol panelden "Runner" projesini seçin
   - "Signing & Capabilities" sekmesine gidin
   - "Team" bölümünden Apple Developer hesabınızı seçin (veya "Add Account" ile ekleyin)
   - Bundle Identifier: `com.zenosmart.connect` (zaten ayarlı olmalı)

3. Terminal'de:

```bash
flutter run -d ios
```

### Release Build (IPA dosyası):

```bash
flutter build ios --release
```

## ✅ Adım 9: macOS Uygulaması Derleme (Opsiyonel)

```bash
flutter run -d macos
```

veya release build:

```bash
flutter build macos
```

## 🔧 Sorun Giderme

### CocoaPods hata verirse:

```bash
cd ios
pod deintegrate
pod install
cd ..
```

### Xcode signing hatası:

- Xcode'da projeyi açın: `open ios/Runner.xcworkspace`
- Signing & Capabilities'den Team seçin
- "Automatically manage signing" işaretli olsun

### Flutter doctor uyarıları:

Her uyarı için `flutter doctor` komutunun önerdiği komutları çalıştırın.

## 📱 Test Etme

Derleme başarılı olduktan sonra:

```bash
# Simulator'da çalıştır
flutter run -d ios

# Veya belirli bir cihaz seç
flutter devices  # Mevcut cihazları listele
flutter run -d <device-id>
```
