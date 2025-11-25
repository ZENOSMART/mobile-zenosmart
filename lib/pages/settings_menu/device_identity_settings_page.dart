import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../helpers/device_settings_helper.dart';
import '../../helpers/device_settings_decoded_helper.dart';
import '../../utils/qr_parser_util.dart';
import '../qr_scan_page.dart';

class DeviceIdentitySettingsPage extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic rxCharacteristic;
  final BluetoothCharacteristic txCharacteristic;
  final bool writeWithoutResponse;
  final String deviceDbId;
  final String deviceName;

  const DeviceIdentitySettingsPage({
    super.key,
    required this.device,
    required this.rxCharacteristic,
    required this.txCharacteristic,
    required this.writeWithoutResponse,
    required this.deviceDbId,
    required this.deviceName,
  });

  @override
  State<DeviceIdentitySettingsPage> createState() =>
      _DeviceIdentitySettingsPageState();
}

class _DeviceIdentitySettingsPageState
    extends State<DeviceIdentitySettingsPage> {
  StreamSubscription<List<int>>? _txCharSub;
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  bool _isRequested = false;
  Timer? _timeoutTimer;
  bool _isReadOnly = true; // true: readonly, false: editable

  // Text controllers for editable fields
  final _devEuiController = TextEditingController();
  final _joinEuiController = TextEditingController();
  final _deviceAddrController = TextEditingController();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

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
    _requestIdentitySettings();
  }

  @override
  void dispose() {
    _txCharSub?.cancel();
    _timeoutTimer?.cancel();
    _devEuiController.dispose();
    _joinEuiController.dispose();
    _deviceAddrController.dispose();
    super.dispose();
  }

  Future<void> _requestIdentitySettings() async {
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

      // Timeout timer (10 saniye)
      _timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && _isLoading) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No response from device. Please try again.';
          });
        }
      });

      // Identity settings isteği gönder (groupId: 3)
      debugPrint('📤 Identity settings isteniyor (groupId: 3)...');
      final commandBytes = DeviceSettingsHelper.createDeviceSettingsRequest(
        requestGroupId: 3,
      );
      debugPrint('📤 Identity settings istek bytes: $commandBytes');

      if (widget.rxCharacteristic.properties.writeWithoutResponse) {
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

      debugPrint('✅ Identity settings isteği gönderildi');
    } catch (e) {
      debugPrint('❌ Identity settings istek hatası: $e');
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
      debugPrint('📩 Identity settings sayfasına veri geldi');
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

          if (result != null && result.groupId == 3) {
            if (result.identity != null) {
              debugPrint('✅ Identity settings alındı: ${result.identity}');
              // Timeout timer'ı iptal et
              _timeoutTimer?.cancel();
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = null;
                  // Düzenlenebilir alanları cihazdan gelen değerlerle doldur
                  _devEuiController.text = result.identity!.devEui;
                  _joinEuiController.text = result.identity!.joinEui;
                  _deviceAddrController.text = result.identity!.deviceAddr;
                });
              }
            } else {
              debugPrint('⚠️ Identity settings parse edilemedi');
              _timeoutTimer?.cancel();
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'Identity settings could not be parsed';
                });
              }
            }
          } else {
            debugPrint('⚠️ Beklenen groupId 3 değil: ${result?.groupId}');
          }
        } else {
          debugPrint('⚠️ Beklenen OpCode DS değil: $opCodeStr');
        }
      }
    } catch (e) {
      debugPrint('❌ Identity settings veri işleme hatası: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Data processing error: $e';
        });
      }
    }
  }

  Future<void> _refreshIdentitySettings() async {
    _isRequested = false;
    _timeoutTimer?.cancel();
    _txCharSub?.cancel();
    await _requestIdentitySettings();
  }

  Future<void> _scanQr() async {
    final raw = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScanPage()));
    if (raw == null || raw.isEmpty) return;

    final qrData = QrParserUtil.parse(raw);
    final devEui = QrParserUtil.extractDevEui(qrData);
    final joinEui = QrParserUtil.extractJoinEui(qrData);
    final devAddr = QrParserUtil.extractDeviceAddr(qrData);

    setState(() {
      if (devEui != null) _devEuiController.text = devEui;
      if (joinEui != null) _joinEuiController.text = joinEui;
      if (devAddr != null) _deviceAddrController.text = devAddr;
    });
  }

  List<int>? _hexStringToBytes(String hex) {
    final cleanHex = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleanHex.isEmpty) return null;
    if (cleanHex.length % 2 != 0) return null;

    final bytes = <int>[];
    for (var i = 0; i < cleanHex.length; i += 2) {
      final byte = int.tryParse(cleanHex.substring(i, i + 2), radix: 16);
      if (byte == null) return null;
      bytes.add(byte);
    }
    return bytes;
  }

  Future<void> _sendIdentitySettingsToDevice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Onay dialog'u göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text(
          'Connection settings will be sent to the device. Do you confirm this action?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Send'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final devEui = _devEuiController.text.trim();
      final joinEui = _joinEuiController.text.trim();
      final deviceAddrStr = _deviceAddrController.text.trim();

      // DeviceAddr'ı parse et (4 byte olmalı)
      List<int>? deviceAddrBytes;
      if (deviceAddrStr.isNotEmpty) {
        deviceAddrBytes = _hexStringToBytes(deviceAddrStr);
        if (deviceAddrBytes == null || deviceAddrBytes.length != 4) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'DeviceAddr must be a 4 byte hex value (e.g.: 01020304)',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      setState(() {
        _isSending = true;
        _errorMessage = null;
      });

      // Identity settings paketini oluştur
      final packet = DeviceSettingsHelper.createDeviceCredentials(
        devEui: devEui,
        joinEui: joinEui,
        deviceAddr: deviceAddrBytes,
        counter: 1,
        groupId: 3,
      );

      debugPrint('📤 Identity settings paketi gönderiliyor...');
      debugPrint('📤 Packet length: ${packet.length} bytes');

      // RX characteristic üzerinden gönder
      if (widget.writeWithoutResponse) {
        await widget.rxCharacteristic.write(packet, withoutResponse: true);
      } else {
        await widget.rxCharacteristic.write(packet, withoutResponse: false);
      }

      debugPrint('✅ Identity settings paketi gönderildi');

      if (mounted) {
        setState(() {
          _isSending = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection settings sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Identity settings gönderme hatası: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
          _errorMessage = 'Connection settings could not be sent: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection settings could not be sent: $e'),
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
        title: const Text('Connection Settings'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshIdentitySettings,
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
                  Text('Retrieving connection settings from device...'),
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
                    onPressed: _refreshIdentitySettings,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
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
                      label: 'DevEUI',
                      controller: _devEuiController,
                      hint: '16 hex characters (e.g.: 0102030405060708)',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      label: 'JoinEUI',
                      controller: _joinEuiController,
                      hint: '16 hex characters (e.g.: 0102030405060708)',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      label: 'DeviceAddr (optional)',
                      controller: _deviceAddrController,
                      hint: '8 hex characters (e.g.: 01020304)',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: _fieldHeight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isReadOnly ? null : _scanQr,
                        icon: const Icon(Icons.qr_code_scanner, size: 22),
                        label: const Text('Scan QR Code'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: _fieldHeight,
                      child: ElevatedButton.icon(
                        onPressed: (_isReadOnly || _isSending)
                            ? null
                            : _sendIdentitySettingsToDevice,
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
                          _isSending
                              ? 'Sending...'
                              : 'Send Connection Settings',
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
            readOnly: _isReadOnly,
            decoration: _buildInputDecoration(hintText: hint),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                if (label.contains('opsiyonel')) {
                  return null;
                }
                return 'This field is required';
              }
              final cleanHex = value.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
              if (label.contains('DevEUI') || label.contains('JoinEUI')) {
                if (cleanHex.length != 16) {
                  return 'Must be 16 hex characters';
                }
              } else if (label.contains('DeviceAddr')) {
                if (cleanHex.isNotEmpty && cleanHex.length != 8) {
                  return 'Must be 8 hex characters';
                }
              }
              return null;
            },
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
