import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../helpers/device_info_data_helper.dart';

class DeviceFirmwareInfoSettingsPage extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic rxCharacteristic;
  final BluetoothCharacteristic txCharacteristic;
  final bool writeWithoutResponse;
  final String deviceDbId;
  final String deviceName;

  const DeviceFirmwareInfoSettingsPage({
    super.key,
    required this.device,
    required this.rxCharacteristic,
    required this.txCharacteristic,
    required this.writeWithoutResponse,
    required this.deviceDbId,
    required this.deviceName,
  });

  @override
  State<DeviceFirmwareInfoSettingsPage> createState() =>
      _DeviceFirmwareInfoSettingsPageState();
}

class _DeviceFirmwareInfoSettingsPageState
    extends State<DeviceFirmwareInfoSettingsPage> {
  // Text controllers (version format: "major.minor.patch" e.g. "2.0.0")
  final _hwVersionController = TextEditingController();
  final _swVersionController = TextEditingController();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isRequested = false;
  String? _errorMessage;
  StreamSubscription<List<int>>? _txCharSub;
  Timer? _timeoutTimer;

  // Stil sabitleri
  static const _fieldHeight = 56.0;

  @override
  void initState() {
    super.initState();
    _requestDeviceInfo();
  }

  @override
  void dispose() {
    _txCharSub?.cancel();
    _timeoutTimer?.cancel();
    _hwVersionController.dispose();
    _swVersionController.dispose();
    super.dispose();
  }

  Future<void> _requestDeviceInfo() async {
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

      // Device Info request gönder
      final commandBytes = DeviceInfoDataHelper.createDeviceInfoRequest();

      debugPrint('📤 Device Info request gönderiliyor...');
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

      debugPrint('✅ Device Info request gönderildi');

      // 5 saniye bekle, eğer yanıt gelmezse hata göster
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _isLoading) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No response from device. Please try again.';
          });
        }
      });
    } catch (e) {
      debugPrint('❌ Device Info request hatası: $e');
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
      debugPrint('📥 Device Info response alındı: ${data.length} bytes');

      // DI response'u parse et
      final response = DeviceInfoDataHelper.parseDeviceInfoResponse(data);

      if (response != null) {
        debugPrint(
          '✅ Device Info parse edildi: HW ${response.hwVersionMajor}.${response.hwVersionMinor}.${response.hwVersionPatch}, SW ${response.swVersionMajor}.${response.swVersionMinor}.${response.swVersionPatch}',
        );

        if (mounted) {
          setState(() {
            _hwVersionController.text =
                '${response.hwVersionMajor}.${response.hwVersionMinor}.${response.hwVersionPatch}';
            _swVersionController.text =
                '${response.swVersionMajor}.${response.swVersionMinor}.${response.swVersionPatch}';
            _isLoading = false;
            _errorMessage = null;
          });
        }

        _timeoutTimer?.cancel();
        _txCharSub?.cancel();
      }
    } catch (e) {
      debugPrint('❌ Device Info parse hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(
        title: const Text('Firmware Info Settings'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _isRequested = false;
              _requestDeviceInfo();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _isRequested = false;
                      _requestDeviceInfo();
                    },
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
                    _buildSectionTitle('Hardware Version'),
                    _buildTextField(controller: _hwVersionController),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Software Version'),
                    _buildTextField(controller: _swVersionController),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? hint,
  }) {
    return SizedBox(
      height: _fieldHeight,
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: _buildInputDecoration(hintText: hint),
      ),
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
