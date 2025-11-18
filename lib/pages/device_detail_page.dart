import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../repositories/device_repository.dart';
import '../repositories/device_detail_repository.dart';
import '../helpers/send_data.dart';
import '../helpers/decoded_data.dart';
import '../helpers/sensor_data_helper.dart';
import '../helpers/device_settings_helper.dart';
import '../helpers/device_settings_decoded_helper.dart';
import '../pages/live_control_page.dart';
import '../pages/program_page.dart';
import '../pages/settings_menu/device_settings_menu_page.dart';
import '../widgets/device_weather_bar.dart';
import '../widgets/device_sunset_sunrise_bar.dart';
import '../widgets/sensor_data_widget.dart';

class DeviceDetailPage extends StatefulWidget {
  final BluetoothDevice device;
  final String deviceName;

  const DeviceDetailPage({
    super.key,
    required this.device,
    required this.deviceName,
  });

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _txCharSub;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  bool _isTryingToConnect = false;
  Timer? _reconnectTimer;
  bool _userInitiatedDisconnect = false;
  BluetoothCharacteristic? _rxChar;
  BluetoothCharacteristic? _txChar;
  SensorDataResult? _latestSensorData;
  String? _deviceDbId;
  String _deviceName = '';
  bool _rxSupportsWriteWithoutResponse = false;
  bool _configSettingsRequested = false;
  bool _sensorDataRequested = false;
  DeviceConfigSettings? _deviceConfigSettings;
  bool _locationWarningShown = false;
  bool _timeWarningShown = false;

  @override
  void initState() {
    super.initState();
    _deviceName = widget.deviceName;
    _connSub = widget.device.connectionState.listen((s) {
      setState(() => _connectionState = s);
      if (s == BluetoothConnectionState.connected) {
        _cancelReconnectTimer();
        _isTryingToConnect = false;
        _userInitiatedDisconnect = false;
        _listenToDevice();
      } else if (s == BluetoothConnectionState.disconnected) {
        _txCharSub?.cancel();
        _txCharSub = null;
        setState(() {
          _rxChar = null;
          _txChar = null;
        });
        if (!_userInitiatedDisconnect) {
          _scheduleReconnect();
        }
      }
    });
    _connect();
  }

  @override
  void dispose() {
    _cancelReconnectTimer();
    _connSub?.cancel();
    _txCharSub?.cancel();
    _disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_isTryingToConnect) return;
    _userInitiatedDisconnect = false;
    _isTryingToConnect = true;
    try {
      await widget.device.connect(timeout: const Duration(seconds: 10));
    } catch (_) {
      // Zaten bağlıysa veya zaman aşımı: reconnect mekanizması devreye girecek
    } finally {
      _isTryingToConnect = false;
    }
  }

  Future<void> _disconnect() async {
    _cancelReconnectTimer();
    _userInitiatedDisconnect = true;
    try {
      await widget.device.disconnect();
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    _cancelReconnectTimer();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      // Eğer kullanıcı bu arada manuel kesmişse tekrar bağlanma yapma
      if (!_userInitiatedDisconnect) {
        _connect();
      }
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Future<void> _listenToDevice() async {
    try {
      _configSettingsRequested = false;
      _sensorDataRequested = false;
      // Veritabanından cihaz bilgilerini al
      final deviceRepo = const DeviceRepository();
      final deviceData = await deviceRepo.getByUnique(
        widget.device.remoteId.str,
      );

      if (deviceData == null) {
        debugPrint('❌ Cihaz veritabanında bulunamadı');
        return;
      }

      final deviceId = deviceData['id'] as String;
      setState(() {
        _deviceDbId = deviceId;
      });
      final detailRepo = const DeviceDetailRepository();
      final detailData = await detailRepo.getByDeviceId(_deviceDbId!);

      String? savedTxCharUuid = detailData?['tx_char_uuid'] as String?;
      String? savedRxCharUuid = detailData?['rx_char_uuid'] as String?;
      String? savedUartServiceUuid =
          detailData?['uart_service_uuid'] as String?;

      debugPrint('📦 Veritabanından alınan UUID\'ler:');
      debugPrint('  UART Service: $savedUartServiceUuid');
      debugPrint('  RX Char: $savedRxCharUuid');
      debugPrint('  TX Char: $savedTxCharUuid');

      // UUID'ler yoksa bağlanma
      if (savedUartServiceUuid == null ||
          savedRxCharUuid == null ||
          savedTxCharUuid == null) {
        debugPrint(
          '❌ UUID\'ler veritabanında bulunamadı, bağlantı iptal ediliyor',
        );
        return;
      }

      // Servisleri keşfet
      final services = await widget.device.discoverServices();
      debugPrint('🔍 Servisler keşfedildi, UUID\'lerle eşleştiriliyor...');

      for (var service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();

        // Sadece veritabanındaki UUID ile eşleştir
        if (serviceUuid == savedUartServiceUuid.toLowerCase()) {
          debugPrint('✓ UART servisi bulundu: $serviceUuid');

          for (var char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();

            // RX karakteristiği - sadece DB'den
            if (charUuid == savedRxCharUuid.toLowerCase()) {
              if (char.properties.write ||
                  char.properties.writeWithoutResponse) {
                setState(() {
                  _rxChar = char;
                  _rxSupportsWriteWithoutResponse =
                      char.properties.writeWithoutResponse;
                });
                debugPrint(
                  '✓ RX karakteristiği bulundu ve state\'e kaydedildi: $charUuid',
                );
              }
            }

            // TX karakteristiği - sadece DB'den
            if (charUuid == savedTxCharUuid.toLowerCase()) {
              debugPrint(
                '🔔 TX Properties: notify=${char.properties.notify}, indicate=${char.properties.indicate}',
              );

              if (char.properties.notify || char.properties.indicate) {
                await char.setNotifyValue(true);

                // State'e kaydet
                setState(() {
                  _txChar = char;
                });
                debugPrint(
                  '✓ TX karakteristiği bulundu ve state\'e kaydedildi: $charUuid',
                );

                _txCharSub = char.lastValueStream.listen((data) async {
                  if (data.isNotEmpty) {
                    // Cihazdan veri geldiğini logla
                    debugPrint('🔔 ========================================');
                    debugPrint('🔔 CİHAZDAN DATA GELDİ!');
                    debugPrint('📩 RAW BYTES (İLK HALİ): $data');
                    debugPrint('📩 BYTES LENGTH: ${data.length}');

                    // Hex formatında göster
                    final hexString = data
                        .map(
                          (b) =>
                              b.toRadixString(16).padLeft(2, '0').toUpperCase(),
                        )
                        .join(' ');

                    debugPrint('📩 HEX: $hexString');

                    // İlk 2 byte'ı string olarak göster
                    if (data.length >= 2) {
                      final opCodeStr = String.fromCharCodes([
                        data[0],
                        data[1],
                      ]);
                      debugPrint(
                        '📩 OpCode (String): "$opCodeStr" (${data[0]}, ${data[1]})',
                      );
                    }

                    debugPrint('🔔 ========================================');

                    // OpCode'u kontrol et
                    if (data.length >= 2) {
                      final opCodeStr = String.fromCharCodes([
                        data[0],
                        data[1],
                      ]);

                      // DI OpCode'unu kontrol et - firmware info settings için
                      if (opCodeStr == 'DI') {
                        debugPrint(
                          '📩 DI OpCode algılandı, firmware info settings sayfasına bırakılıyor',
                        );
                        return; // DI response'unu firmware info settings page'e bırak
                      }

                      // TC, LC, TR mesajlarını ignore et - program_page kendi stream'ini dinliyor
                      // Log basmadan sessizce ignore et
                      if (opCodeStr == 'TC' ||
                          opCodeStr == 'LC' ||
                          opCodeStr == 'TR') {
                        return; // Bu mesajları program_page işleyecek
                      }
                    }

                    // OpCodeHandler ile decode et
                    try {
                      // Device ID'yi al
                      final deviceRepo = const DeviceRepository();
                      final device = await deviceRepo.getByUnique(
                        widget.device.remoteId.str,
                      );
                      final deviceId = device?['id'] as String? ?? '';

                      // OpCodeHandler ile decode et
                      final sensorData = await OpCodeHandler.handleData(
                        deviceId,
                        data,
                      );

                      // Eğer Sensor Data ise state'e kaydet ve widget'ı göster
                      if (sensorData != null) {
                        setState(() {
                          _latestSensorData = sensorData;
                          _sensorDataRequested =
                              false; // Sensör verisi alındı, yeniden istenebilir
                        });
                        debugPrint(
                          '✅ Sensor Data alındı ve widget güncellendi',
                        );
                      } else {
                        // Sadece DS mesajlarını parse et (TC, LC, TR zaten yukarıda filtrelendi)
                        final opCodeStr = data.length >= 2
                            ? String.fromCharCodes([data[0], data[1]])
                            : '';
                        if (opCodeStr == 'DS') {
                          final settingsResult =
                              DeviceSettingsDecodedHelper.parse(deviceId, data);

                          if (settingsResult != null &&
                              settingsResult.groupId == 5) {
                            if (settingsResult.config != null) {
                              setState(() {
                                _deviceConfigSettings = settingsResult.config;
                              });
                              debugPrint(
                                '✅ Config ayarları alındı: ${settingsResult.config}',
                              );
                              debugPrint(
                                '📍 Widget\'lara geçirilecek: latitude=${settingsResult.config!.latitude}, longitude=${settingsResult.config!.longitude}',
                              );

                              // Latitude ve longitude 0 ise uyarı göster
                              if (mounted &&
                                  (settingsResult.config!.latitude == 0 ||
                                      settingsResult.config!.longitude == 0) &&
                                  !_locationWarningShown) {
                                _locationWarningShown = true;
                                Future.delayed(
                                  const Duration(milliseconds: 500),
                                  () {
                                    if (mounted) {
                                      _showLocationWarningDialog();
                                    }
                                  },
                                );
                              }

                              // Tarih 01/01/2000 ise uyarı göster
                              if (mounted &&
                                  settingsResult.config!.year == 2000 &&
                                  settingsResult.config!.month == 1 &&
                                  settingsResult.config!.day == 1 &&
                                  !_timeWarningShown) {
                                _timeWarningShown = true;
                                Future.delayed(
                                  const Duration(milliseconds: 800),
                                  () {
                                    if (mounted) {
                                      _showTimeWarningDialog();
                                    }
                                  },
                                );
                              }

                              // Config settings alındıktan sonra sensör verisini iste
                              if (_rxChar != null && !_sensorDataRequested) {
                                debugPrint(
                                  '📤 Config settings alındı, sensör verisi isteniyor...',
                                );
                                // Kısa bir bekleme ekle (config response'un işlenmesi için)
                                Future.delayed(
                                  const Duration(milliseconds: 1000),
                                  () {
                                    if (mounted &&
                                        _rxChar != null &&
                                        !_sensorDataRequested) {
                                      _sendGetSensor(withConfig: false);
                                    }
                                  },
                                );
                              }
                            }
                          }
                        }
                      }
                    } catch (e, stackTrace) {
                      debugPrint('❌ Decode hatası: $e');
                      debugPrint('❌ StackTrace: $stackTrace');
                    }
                  }
                });

                debugPrint('✓ TX karakteristiği dinleniyor');
              }
            }
          }

          // TX dinlenmeye başladıysa ve RX bulunmuşsa, config ve sensör verisi iste
          if (_txCharSub != null && _rxChar != null) {
            // Önce config settings iste
            await _requestConfigSettings();
            // Config settings'in gelmesi için bekle, sonra sensör verisi iste
            // Eğer config settings gelmezse bile sensör verisi istenmeli
            Future.delayed(const Duration(milliseconds: 2000), () {
              if (mounted && _rxChar != null && !_sensorDataRequested) {
                debugPrint(
                  '📤 Config settings bekleme süresi doldu, sensör verisi isteniyor...',
                );
                _sendGetSensor(withConfig: false);
              }
            });
          }

          break;
        }
      }
    } catch (e) {
      debugPrint('❌ Cihaz dinleme hatası: $e');
    }
  }

  Future<void> _sendGetSensor({
    bool withConfig = false,
    bool force = false,
  }) async {
    if (_rxChar == null) {
      debugPrint('❌ RX karakteristiği bulunamadı');
      return;
    }

    // Config ayarlarını iste (sadece bir kez ve sadece withConfig true ise)
    if (withConfig && !_configSettingsRequested && _rxChar != null) {
      await _requestConfigSettings();
      _configSettingsRequested = true;
    }

    // Sensör verisi zaten istenmişse tekrar isteme (force=true ise atla)
    if (!force && _sensorDataRequested) {
      debugPrint('⚠️ Sensör verisi zaten istenmiş, tekrar istenmiyor');
      return;
    }

    debugPrint('📤 sendGetSensor komutu gönderiliyor...');
    try {
      _sensorDataRequested = true;
      final commandBytes = SendData.sendGetSensor();
      debugPrint('📤 sendGetSensor komutu bytes: $commandBytes');

      if (_rxChar!.properties.writeWithoutResponse) {
        await _rxChar!.write(commandBytes, withoutResponse: true);
      } else {
        await _rxChar!.write(commandBytes, withoutResponse: false);
      }

      debugPrint('✅ sendGetSensor komutu gönderildi');
    } catch (e) {
      debugPrint('❌ Komut gönderme hatası: $e');
      _sensorDataRequested = false; // Hata olursa tekrar denenebilsin
    }
  }

  Future<void> _requestConfigSettings() async {
    if (_rxChar == null) {
      debugPrint('❌ RX karakteristiği bulunamadı');
      return;
    }

    debugPrint('📤 Config ayarları isteniyor (groupId: 5)...');
    try {
      final commandBytes = DeviceSettingsHelper.createDeviceSettingsRequest(
        requestGroupId: 5,
      );
      debugPrint('📤 Config ayarları istek bytes: $commandBytes');

      if (_rxChar!.properties.writeWithoutResponse) {
        await _rxChar!.write(commandBytes, withoutResponse: true);
      } else {
        await _rxChar!.write(commandBytes, withoutResponse: false);
      }

      debugPrint('✅ Config ayarları isteği gönderildi');
    } catch (e) {
      debugPrint('❌ Config ayarları istek hatası: $e');
    }
  }

  Future<void> _openLiveControlPage() async {
    if (_deviceDbId == null || _rxChar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waiting for connection for device control.'),
        ),
      );
      return;
    }

    try {
      final initialValues = <int, double>{};
      final sensorData = _latestSensorData;
      if (sensorData != null) {
        for (final channel in sensorData.channels) {
          final code = channel.channelCode;
          if (code != null) {
            initialValues[code] = channel.value;
          }
        }
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveControlPage(
            deviceId: _deviceDbId!,
            rxCharacteristic: _rxChar!,
            writeWithoutResponse: _rxChar!.properties.writeWithoutResponse,
            deviceName: widget.deviceName,
            initialChannelValues: initialValues.isNotEmpty
                ? initialValues
                : null,
          ),
        ),
      );

      if (!mounted) return;
      await _sendGetSensor(withConfig: false);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Page could not be opened: $e')));
    }
  }

  Future<void> _openProgramPage() async {
    if (_deviceDbId == null || _rxChar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waiting for connection for device control.'),
        ),
      );
      return;
    }

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProgramPage(
            rxCharacteristic: _rxChar!,
            txCharacteristic: _txChar,
            writeWithoutResponse: _rxChar!.properties.writeWithoutResponse,
            deviceName: widget.deviceName,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Page could not be opened: $e')));
    }
  }

  Future<void> _openDeviceSettingsPage() async {
    if (_deviceDbId == null || _rxChar == null || _txChar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for device connection...')),
      );
      return;
    }

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeviceSettingsMenuPage(
            device: widget.device,
            rxCharacteristic: _rxChar!,
            txCharacteristic: _txChar!,
            writeWithoutResponse: _rxSupportsWriteWithoutResponse,
            deviceDbId: _deviceDbId!,
            deviceName: widget.deviceName,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settings page could not be opened: $e')),
        );
      }
    }
  }

  // Bağlantı durumu AppBar'da gösterilmiyor; butonlar yeterli

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(title: Text(_deviceName), centerTitle: true),
      body: Column(
        children: [
          // Hava durumu app bar (enlem-boylam bilgisine göre)
          DeviceWeatherBar(
            key: ValueKey(
              'weather_${_deviceConfigSettings?.latitude}_${_deviceConfigSettings?.longitude}',
            ),
            deviceRemoteId: widget.device.remoteId.str,
            latitude: _deviceConfigSettings?.latitude,
            longitude: _deviceConfigSettings?.longitude,
          ),
          // Yeşil ayırıcı çizgi
          // Gün doğumu/batımı bar (enlem-boylam bilgisine göre)
          DeviceSunsetSunriseBar(
            key: ValueKey(
              'sunset_${_deviceConfigSettings?.latitude}_${_deviceConfigSettings?.longitude}',
            ),
            deviceRemoteId: widget.device.remoteId.str,
            latitude: _deviceConfigSettings?.latitude,
            longitude: _deviceConfigSettings?.longitude,
          ),
          // Sensor data widget (scrollable)
          Expanded(
            child: SingleChildScrollView(
              child: _latestSensorData != null
                  ? SensorDataWidget(sensorData: _latestSensorData!)
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'Waiting for sensor data...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
            ),
          ),
          // Bağlantı butonları - Sabit en altta
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008E46),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed:
                        _connectionState == BluetoothConnectionState.connected
                        ? null
                        : _connect,
                    icon: const Icon(Icons.link, size: 20),
                    label: const Text('Connect'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008E46),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed:
                        _connectionState == BluetoothConnectionState.connected
                        ? _disconnect
                        : null,
                    icon: const Icon(Icons.link_off, size: 20),
                    label: const Text('Disconnect'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _connectionState ==
                                BluetoothConnectionState.connected &&
                            _rxChar != null
                        ? const Color(0xFF008E46)
                        : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  onPressed:
                      _connectionState == BluetoothConnectionState.connected &&
                          _rxChar != null
                      ? () => _sendGetSensor(force: true)
                      : null,
                  child: const Icon(Icons.refresh, size: 24),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomButton(
                  icon: Icons.tune,
                  label: 'Control',
                  enabled: _deviceDbId != null && _rxChar != null,
                  onPressed: () {
                    _openLiveControlPage();
                  },
                ),
                _buildBottomButton(
                  icon: Icons.view_list,
                  label: 'Program',
                  enabled: _deviceDbId != null && _rxChar != null,
                  onPressed: _openProgramPage,
                ),
                _buildBottomButton(
                  icon: Icons.settings,
                  label: 'Settings',
                  enabled:
                      _deviceDbId != null && _rxChar != null && _txChar != null,
                  onPressed: _openDeviceSettingsPage,
                ),
                _buildBottomButton(
                  icon: Icons.calendar_month,
                  label: 'Calendar',
                  onPressed: () {
                    // TODO: Takvim işlevi
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool enabled = true,
  }) {
    final color = enabled ? const Color(0xFF008E46) : Colors.grey;

    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationWarningDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Location Not Set'),
            ],
          ),
          content: const Text(
            'Please set the device\'s latitude and longitude from the Settings section.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openDeviceSettingsPage();
              },
              child: const Text('Go to Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showTimeWarningDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Time Not Set'),
            ],
          ),
          content: const Text(
            'Please set the device\'s time from the Settings > Device Config section.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openDeviceSettingsPage();
              },
              child: const Text('Go to Settings'),
            ),
          ],
        );
      },
    );
  }
}
