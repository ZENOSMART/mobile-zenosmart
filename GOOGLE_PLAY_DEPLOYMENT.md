# Google Play'e Yükleme Rehberi

## ÖNEMLİ: Google Play App Signing

Google Play **otomatik olarak** app signing key'inizi yönetir. Siz sadece **upload keystore** oluşturursunuz.

### Adım 1: Upload Keystore Oluşturma

1. Terminal/Command Prompt'u açın
2. Android klasörüne gidin:

   ```bash
   cd android
   ```

3. Keystore oluşturun (PowerShell'de):

   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload -storetype JKS
   ```

4. Sorulara cevap verin:

   - **Password**: Güvenli bir şifre seçin (unutmayın!)
   - **Name**: İsim (örn: Zenosmart)
   - **Organizational Unit**: Departman (opsiyonel)
   - **Organization**: Şirket adı (örn: Zenosmart)
   - **City**: Şehir
   - **State**: Eyalet/İl
   - **Country Code**: Ülke kodu (TR için: TR)

5. Keystore dosyası `android/upload-keystore.jks` olarak oluşturulacak

### Adım 2: key.properties Dosyası Oluşturma

`android/key.properties` dosyası oluşturun ve şu bilgileri ekleyin:

```
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

**ÖNEMLİ**:

- `key.properties` dosyasını **ASLA** Git'e commit etmeyin!
- `.gitignore` dosyasına ekleyin: `android/key.properties`
- `android/upload-keystore.jks` dosyasını da `.gitignore`'a ekleyin

### Adım 3: .gitignore Güncelleme

`android/.gitignore` dosyasına ekleyin:

```
key.properties
upload-keystore.jks
*.jks
```

### Adım 4: Uygulama Versiyonunu Kontrol Etme

`pubspec.yaml` dosyasında versiyon:

```yaml
version: 1.0.0+1
```

- `1.0.0` = versionName (kullanıcıya gösterilen)
- `1` = versionCode (her yüklemede artmalı)

### Adım 5: Release Build (AAB) Oluşturma

```bash
flutter build appbundle --release
```

Dosya şurada oluşur:
`build/app/outputs/bundle/release/app-release.aab`

### Adım 6: Google Play Console

1. https://play.google.com/console adresine gidin
2. Google hesabınızla giriş yapın
3. Developer hesabı oluşturun ($25 tek seferlik ücret)
4. Yeni uygulama oluşturun
5. **App Signing** bölümünde Google Play App Signing'i etkinleştirin

### Adım 7: İlk Yükleme

1. Google Play Console'da "Production" veya "Internal testing" seçin
2. "Create new release" tıklayın
3. AAB dosyasını yükleyin (`app-release.aab`)
4. Google Play otomatik olarak:
   - Upload keystore'unuzu kullanarak app signing key oluşturur
   - Uygulamanızı app signing key ile imzalar

### Adım 8: Sonraki Güncellemeler

Her güncellemede:

1. `pubspec.yaml`'da versionCode'u artırın (örn: `1.0.1+2`)
2. Aynı upload keystore ile build alın
3. Google Play otomatik olarak app signing key ile yeniden imzalar

## Güvenlik Notları

✅ **YAPILMASI GEREKENLER:**

- Upload keystore şifresini güvenli bir yerde saklayın
- key.properties dosyasını Git'e eklemeyin
- Keystore dosyasını yedekleyin

❌ **YAPILMAMASI GEREKENLER:**

- Upload keystore'u kaybetmeyin (Google Play'den kurtarılabilir ama zor)
- Şifreleri paylaşmayın
- Keystore dosyasını Git'e commit etmeyin

## Upload Keystore Kaybolursa

Google Play Console'da:

1. App Signing bölümüne gidin
2. "Request upload key reset" seçeneğini kullanın
3. Google yeni bir upload key oluşturur
