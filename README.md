# Zenosmart Connect

Zenosmart Connect - Device management application.

## Gereksinimler

### Mac için Gereksinimler:

**Temel Gereksinimler:**

- macOS (en az macOS 10.15 veya üzeri)
- Flutter SDK (en az 3.8.0)

**Android Derlemesi için (Xcode GEREKMEZ!):**

- Java JDK 11 veya üzeri
- Android SDK (Android Studio ile birlikte gelir veya komut satırından yüklenebilir)
- Android Studio (opsiyonel, sadece Android Studio kullanmak istiyorsanız)

**iOS Derlemesi için (Xcode ZORUNLU):**

- Xcode (App Store'dan ücretsiz)
- CocoaPods (`sudo gem install cocoapods`)

**macOS Derlemesi için (Xcode ZORUNLU):**

- Xcode (App Store'dan ücretsiz)

## Mac'te Kurulum ve Derleme

### 1. Projeyi İndirin

```bash
git clone https://github.com/ZENOSMART/mobile-zenosmart.git
cd mobile-zenosmart
```

### 2. Flutter Bağımlılıklarını Yükleyin

```bash
flutter pub get
```

### 3. iOS Bağımlılıklarını Yükleyin (Sadece iOS derlemek istiyorsanız)

```bash
cd ios
pod install
cd ..
```

**Not:** Sadece Android derlemek istiyorsanız bu adımı atlayabilirsiniz.

### 4. Flutter Doctor Kontrolü

```bash
flutter doctor
```

Tüm gereksinimlerin yüklü olduğundan emin olun.

### 5. Derleme

#### iOS için Derleme:

```bash
# Simulator için
flutter run -d ios

# Fiziksel cihaz için (Xcode'da signing ayarları gerekli)
flutter build ios
```

#### Android için Derleme (Mac'te):

```bash
# Debug build
flutter run -d android

# Release build
flutter build apk
```

#### macOS için Derleme:

```bash
# Debug
flutter run -d macos

# Release
flutter build macos
```

## Önemli Notlar

### Xcode Gereksinimi:

- **Android derlemesi için Xcode GEREKMEZ!** ✅
- **iOS derlemesi için Xcode ZORUNLU** ❌
- **macOS derlemesi için Xcode ZORUNLU** ❌

### Android Derlemesi (Xcode olmadan):

Mac'te Android derlemek için sadece şunlar yeterli:

1. Flutter SDK
2. Java JDK 11+
3. Android SDK (Android Studio veya komut satırı araçları)

```bash
# Android SDK yolunu ayarlayın (Android Studio yüklüyse otomatik algılanır)
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Android derlemesi
flutter build apk
```

### iOS Derlemesi için:

- Xcode'da projeyi açın: `open ios/Runner.xcworkspace`
- Signing & Capabilities bölümünden Apple Developer hesabınızı ekleyin
- Bundle Identifier: `com.zenosmart.connect`

### Hassas Dosyalar:

Aşağıdaki dosyalar `.gitignore`'a eklenmiştir ve GitHub'da bulunmaz:

- `android/key.properties`
- `android/upload-keystore.jks`
- `android/local.properties`

Bu dosyaları yerel olarak oluşturmanız gerekebilir.

## Platform Desteği

- ✅ iOS (iOS 12.0+)
- ✅ Android (minSdk 23)
- ✅ macOS
- ✅ Web
- ✅ Linux
- ✅ Windows

## Geliştirme

Proje Flutter 3.8.0+ SDK ile geliştirilmiştir.

Daha fazla bilgi için [Flutter dokümantasyonuna](https://docs.flutter.dev/) bakabilirsiniz.
