import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../helpers/device_settings_helper.dart';
import '../../helpers/device_settings_decoded_helper.dart';
import '../map_pick_page.dart';

class DeviceConfigSettingsPage extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic rxCharacteristic;
  final BluetoothCharacteristic txCharacteristic;
  final bool writeWithoutResponse;
  final String deviceDbId;
  final String deviceName;

  const DeviceConfigSettingsPage({
    super.key,
    required this.device,
    required this.rxCharacteristic,
    required this.txCharacteristic,
    required this.writeWithoutResponse,
    required this.deviceDbId,
    required this.deviceName,
  });

  @override
  State<DeviceConfigSettingsPage> createState() =>
      _DeviceConfigSettingsPageState();
}

class _DeviceConfigSettingsPageState extends State<DeviceConfigSettingsPage> {
  StreamSubscription<List<int>>? _txCharSub;
  DeviceConfigSettings? _configSettings;
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  bool _isRequested = false;
  Timer? _timeoutTimer;

  // Latitude ve longitude değerleri (map pick'ten gelecek veya cihazdan alınacak)
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _requestConfigSettings();
  }

  @override
  void dispose() {
    _txCharSub?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestConfigSettings() async {
    if (_isRequested) return;
    _isRequested = true;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TX characteristic'ten veri dinlemeye başla
      // Notify zaten device_detail_page'de açık olmalı
      // lastValueStream'i dinle (birden fazla listener desteklenir)
      _txCharSub = widget.txCharacteristic.lastValueStream.listen(
        (data) {
          if (data.isNotEmpty) {
            _handleReceivedData(data);
          }
        },
        onError: (error) {
          debugPrint('❌ TX stream hatası: $error');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Data retrieval error: $error';
            });
          }
        },
      );

      // Kısa bir bekleme süresi ekle (stream'in aktif olması için)
      await Future.delayed(const Duration(milliseconds: 300));

      // Config settings isteğini gönder
      final commandBytes = DeviceSettingsHelper.createDeviceSettingsRequest(
        requestGroupId: 5,
        counter: 1,
      );

      debugPrint('📤 Config settings isteği gönderiliyor...');
      debugPrint('📤 Bytes: $commandBytes');

      if (widget.writeWithoutResponse) {
        await widget.rxCharacteristic.write(
          commandBytes,
          withoutResponse: true,
        );
      } else {
        await widget.rxCharacteristic.write(
          commandBytes,
          withoutResponse: false,
        );
      }

      debugPrint('✅ Config settings isteği gönderildi');

      // 5 saniye bekle, eğer yanıt gelmezse hata göster
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _configSettings == null && _isLoading) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No response from device. Please try again.';
          });
        }
      });
    } catch (e) {
      debugPrint('❌ Config settings istek hatası: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Request could not be sent: $e';
        });
      }
    }
  }

  void _handleReceivedData(List<int> data) {
    try {
      debugPrint('📩 Config settings sayfasına veri geldi');
      debugPrint('📩 Data length: ${data.length}');
      debugPrint('📩 Data: $data');

      // İlk 2 byte'ı kontrol et (OpCode)
      if (data.length >= 2) {
        final opCodeStr = String.fromCharCodes([data[0], data[1]]);
        debugPrint('📩 OpCode: $opCodeStr');

        // DS (Device Settings) opcode'unu kontrol et
        if (opCodeStr == 'DS') {
          final result = DeviceSettingsDecodedHelper.parse(
            widget.deviceDbId,
            data,
          );

          if (result != null && result.groupId == 5) {
            if (result.config != null) {
              debugPrint('✅ Config settings alındı: ${result.config}');
              // Timeout timer'ı iptal et
              _timeoutTimer?.cancel();
              if (mounted) {
                setState(() {
                  _configSettings = result.config;
                  _isLoading = false;
                  _errorMessage = null;
                  // Cihazdan gelen değerleri kaydet
                  _latitude = result.config!.latitude;
                  _longitude = result.config!.longitude;
                });
              }
            } else {
              debugPrint('⚠️ Config settings parse edilemedi');
              _timeoutTimer?.cancel();
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'Config settings parse edilemedi';
                });
              }
            }
          } else {
            debugPrint('⚠️ Beklenen groupId 5 değil: ${result?.groupId}');
          }
        } else {
          debugPrint('⚠️ Beklenen OpCode DS değil: $opCodeStr');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Veri işleme hatası: $e');
      debugPrint('❌ StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Data processing error: $e';
        });
      }
    }
  }

  Future<void> _refreshConfigSettings() async {
    _timeoutTimer?.cancel();
    _txCharSub?.cancel();
    _isRequested = false;
    _configSettings = null;
    await _requestConfigSettings();
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(
        builder: (_) =>
            MapPickPage(initialLat: _latitude, initialLng: _longitude),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
    }
  }

  Future<void> _sendConfigToDevice() async {
    if (_latitude == null ||
        _longitude == null ||
        _latitude == 0 ||
        _longitude == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a location')));
      return;
    }

    try {
      setState(() {
        _isSending = true;
        _errorMessage = null;
      });

      // Config paketini oluştur (yeni DeviceSettingsHelper kullan)
      final packet = DeviceSettingsHelper.createDeviceConfigSettings(
        latitude: _latitude!,
        longitude: _longitude!,
        counter: 1,
      );

      debugPrint('📤 Config paketi gönderiliyor...');
      debugPrint('📤 Latitude: $_latitude, Longitude: $_longitude');
      debugPrint('📤 Packet length: ${packet.length} bytes');

      // RX characteristic üzerinden gönder
      if (widget.writeWithoutResponse) {
        await widget.rxCharacteristic.write(packet, withoutResponse: true);
      } else {
        await widget.rxCharacteristic.write(packet, withoutResponse: false);
      }

      debugPrint('✅ Config paketi gönderildi');

      if (mounted) {
        setState(() {
          _isSending = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Config sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Config gönderme hatası: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
          _errorMessage = 'Config could not be sent: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Config could not be sent: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(
        title: const Text('Config and Time Settings'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshConfigSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Retrieving config information from device...'),
                ],
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _refreshConfigSettings,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _configSettings == null
          ? const Center(child: Text('Config settings not found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Location Information'),
                  if (_latitude != null && _longitude != null) ...[
                    _buildInfoCard(
                      'Latitude',
                      _latitude!.toStringAsFixed(6),
                      Icons.location_on,
                    ),
                    _buildInfoCard(
                      'Longitude',
                      _longitude!.toStringAsFixed(6),
                      Icons.location_on,
                    ),
                  ] else
                    const Card(
                      color: Colors.white,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Location information not found'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _pickLocation,
                      icon: const Icon(Icons.map),
                      label: const Text('Select from Map'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008E46),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (_configSettings != null) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle('Date & Time Information'),
                    _buildInfoCard(
                      'Date',
                      _formatDate(_configSettings!),
                      Icons.calendar_today,
                    ),
                    _buildTimeTimezoneCard(_configSettings!),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          (_isSending ||
                              _latitude == null ||
                              _longitude == null ||
                              _latitude == 0 ||
                              _longitude == 0)
                          ? null
                          : _sendConfigToDevice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008E46),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSending
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Sending...'),
                              ],
                            )
                          : const Text('Send Time and Config To Device'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    // Tüm ikonlar için aynı renk (#1e325a)
    const iconColor = Color(0xFF1e325a);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: iconColor, size: 20),
        title: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTimeTimezoneCard(DeviceConfigSettings config) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(
          Icons.access_time,
          color: Color(0xFF1e325a),
          size: 20,
        ),
        title: const Text(
          'Time & Timezone',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        subtitle: Text(
          '${_formatTime(config)} • ${_formatTimezone(config.timezone)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _formatDate(DeviceConfigSettings config) {
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final dayNames = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];

    final dayName = config.dayOfWeek < dayNames.length
        ? dayNames[config.dayOfWeek]
        : 'Unknown';
    final monthName = config.month >= 1 && config.month <= 12
        ? monthNames[config.month - 1]
        : 'Unknown';

    return '${dayName}, ${config.day.toString().padLeft(2, '0')} ${monthName} ${config.year}';
  }

  String _formatTime(DeviceConfigSettings config) {
    return '${config.hour.toString().padLeft(2, '0')}:${config.minute.toString().padLeft(2, '0')}:${config.second.toString().padLeft(2, '0')}';
  }

  String _formatTimezone(int timezone) {
    if (timezone == 0) {
      return 'UTC (GMT±0)';
    } else if (timezone > 0) {
      return 'UTC+$timezone (GMT+$timezone)';
    } else {
      return 'UTC$timezone (GMT$timezone)';
    }
  }
}
