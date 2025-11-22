import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../helpers/device_settings_helper.dart';
import '../../helpers/device_settings_decoded_helper.dart';

class DeviceGeneralSettingsPage extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic rxCharacteristic;
  final BluetoothCharacteristic txCharacteristic;
  final bool writeWithoutResponse;
  final String deviceDbId;
  final String deviceName;

  const DeviceGeneralSettingsPage({
    super.key,
    required this.device,
    required this.rxCharacteristic,
    required this.txCharacteristic,
    required this.writeWithoutResponse,
    required this.deviceDbId,
    required this.deviceName,
  });

  @override
  State<DeviceGeneralSettingsPage> createState() =>
      _DeviceGeneralSettingsPageState();
}

class _DeviceGeneralSettingsPageState extends State<DeviceGeneralSettingsPage> {
  StreamSubscription<List<int>>? _txCharSub;
  DeviceSettingsGeneral? _generalSettings;
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  bool _isRequested = false;
  Timer? _timeoutTimer;

  // Text controllers for editable fields
  final _minPackTimeController = TextEditingController();
  final _bleUartWakeupController = TextEditingController();
  final _uplinkIntervalController = TextEditingController();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Boolean for isConfirmed
  bool _isConfirmed = true;
  // Boolean for isConfirmedResendManual
  bool _isConfirmedResendManual = false;

  // Read-only values (cihazdan alınan, değiştirilemez - gönderirken kullanılacak)
  int? _activationType;
  int? _dataRate;

  // Stil sabitleri (add_device_pages ile aynı)
  static const _accentColor = Color(0xFF008E46);
  static const _fieldHeight = 56.0;
  static const _fieldLabelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  @override
  void initState() {
    super.initState();
    _requestGeneralSettings();
  }

  @override
  void dispose() {
    _txCharSub?.cancel();
    _timeoutTimer?.cancel();
    _minPackTimeController.dispose();
    _bleUartWakeupController.dispose();
    _uplinkIntervalController.dispose();
    super.dispose();
  }

  Future<void> _requestGeneralSettings() async {
    if (_isRequested) return;
    _isRequested = true;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TX characteristic'ten veri dinlemeye başla
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

      // General settings isteğini gönder (groupId: 4)
      final commandBytes = DeviceSettingsHelper.createDeviceSettingsRequest(
        requestGroupId: 4,
        counter: 1,
      );

      debugPrint('📤 General settings isteği gönderiliyor...');
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

      debugPrint('✅ General settings isteği gönderildi');

      // 5 saniye bekle, eğer yanıt gelmezse hata göster
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _generalSettings == null && _isLoading) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No response from device. Please try again.';
          });
        }
      });
    } catch (e) {
      debugPrint('❌ General settings istek hatası: $e');
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
      debugPrint('📩 General settings sayfasına veri geldi');
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

          if (result != null && result.groupId == 4) {
            if (result.general != null) {
              debugPrint('✅ General settings alındı: ${result.general}');
              // Timeout timer'ı iptal et
              _timeoutTimer?.cancel();
              if (mounted) {
                setState(() {
                  _generalSettings = result.general;
                  _isLoading = false;
                  _errorMessage = null;
                  // Düzenlenebilir alanları cihazdan gelen değerlerle doldur
                  _minPackTimeController.text = result
                      .general!
                      .minPackTimeSeconds
                      .toString();
                  _bleUartWakeupController.text = result
                      .general!
                      .bleUartWakeupSeconds
                      .toString();
                  _isConfirmed = result.general!.isConfirmed;
                  _isConfirmedResendManual =
                      result.general!.isConfirmedResendManual == 1;
                  // Uplink interval'i dakika olarak göster (cihazdan zaten dakika olarak geliyor)
                  _uplinkIntervalController.text = result
                      .general!
                      .uplinkInterval
                      .toString();
                  // Read-only değerleri kaydet (gönderirken kullanılacak)
                  _activationType = result.general!.activationType ?? 0;
                  _dataRate = result.general!.dataRate ?? 0;
                });
              }
            } else {
              debugPrint('⚠️ General settings parse edilemedi');
              _timeoutTimer?.cancel();
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'General settings parse edilemedi';
                });
              }
            }
          } else {
            debugPrint('⚠️ Beklenen groupId 4 değil: ${result?.groupId}');
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

  Future<void> _refreshGeneralSettings() async {
    _timeoutTimer?.cancel();
    _txCharSub?.cancel();
    _isRequested = false;
    _generalSettings = null;
    await _requestGeneralSettings();
  }

  Future<void> _sendGeneralSettingsToDevice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final minPackTimeSeconds = int.tryParse(_minPackTimeController.text) ?? 0;
      final bleUartWakeupSeconds =
          int.tryParse(_bleUartWakeupController.text) ?? 0;
      // Uplink interval zaten dakika olarak (cihaz dakika bekliyor)
      final uplinkInterval = int.tryParse(_uplinkIntervalController.text) ?? 1;
      final isConfirmedResendManual = _isConfirmedResendManual ? 1 : 0;

      // Read-only değerleri cihazdan alınan değerlerle kullan (eğer yoksa default)
      final activationType = _activationType ?? 0;
      final dataRate = _dataRate ?? 0;

      setState(() {
        _isSending = true;
        _errorMessage = null;
      });

      // General settings paketini oluştur
      final packet = DeviceSettingsHelper.createDeviceGeneralSettings(
        minPackTimeSeconds: minPackTimeSeconds,
        bleUartWakeupSeconds: bleUartWakeupSeconds,
        uplinkInterval: uplinkInterval,
        isConfirmed: _isConfirmed,
        isConfirmedResendManual: isConfirmedResendManual,
        activationType: activationType,
        dataRate: dataRate,
        counter: 1,
      );

      debugPrint('📤 General settings paketi gönderiliyor...');
      debugPrint('📤 Packet length: ${packet.length} bytes');

      // RX characteristic üzerinden gönder
      if (widget.writeWithoutResponse) {
        await widget.rxCharacteristic.write(packet, withoutResponse: true);
      } else {
        await widget.rxCharacteristic.write(packet, withoutResponse: false);
      }

      debugPrint('✅ General settings paketi gönderildi');

      if (mounted) {
        setState(() {
          _isSending = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('General settings sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ General settings gönderme hatası: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
          _errorMessage = 'General settings could not be sent: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('General settings could not be sent: $e'),
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
        title: const Text('General Settings'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshGeneralSettings,
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
                  Text('Retrieving general settings from device...'),
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
                    onPressed: _refreshGeneralSettings,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _generalSettings == null
          ? const Center(child: Text('General settings not found'))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    _buildTextField(
                      label: 'Min Pack Time Seconds',
                      controller: _minPackTimeController,
                      hint: '0-65535',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      label: 'BLE UART Wakeup Seconds',
                      controller: _bleUartWakeupController,
                      hint: '0-65535',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      label: 'Uplink Interval (Minutes)',
                      controller: _uplinkIntervalController,
                      hint: 'Enter minutes',
                    ),
                    const SizedBox(height: 12),
                    _buildSwitchField(
                      label: 'Is Confirmed',
                      value: _isConfirmed,
                      onChanged: (value) {
                        setState(() {
                          _isConfirmed = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSwitchField(
                      label: 'Is Confirmed Resend Manual',
                      value: _isConfirmedResendManual,
                      onChanged: (value) {
                        setState(() {
                          _isConfirmedResendManual = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: _fieldHeight,
                      child: ElevatedButton.icon(
                        onPressed: null,
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send, size: 22),
                        label: Text(
                          _isSending ? 'Sending...' : 'Send General Settings',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _fieldLabelStyle),
        const SizedBox(height: 6),
        SizedBox(
          height: _fieldHeight,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            readOnly: true,
            decoration: _buildInputDecoration(hintText: hint),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'This field is required';
              }
              final number = int.tryParse(value);
              if (number == null) {
                return 'Please enter a valid number';
              }
              // Uplink interval için özel validasyon (dakika cinsinden)
              if (label.contains('Uplink Interval')) {
                if (number < 0) {
                  return 'Please enter a positive number';
                }
                // Maksimum değer: 65535 dakika (uint16 maksimum değeri)
                if (number > 65535) {
                  return 'Please enter a value between 0-65535 minutes';
                }
              } else {
                // Diğer alanlar için standart validasyon
                if (number < 0 || number > 65535) {
                  return 'Please enter a value between 0-65535';
                }
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchField({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _fieldLabelStyle),
        const SizedBox(height: 6),
        Container(
          height: _fieldHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  value ? 'Yes' : 'No',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: value,
                activeColor: Colors.white,
                activeTrackColor: _accentColor,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: _accentColor.withOpacity(0.3),
                trackOutlineColor: MaterialStateProperty.resolveWith(
                  (states) => Colors.transparent,
                ),
                onChanged: null,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
