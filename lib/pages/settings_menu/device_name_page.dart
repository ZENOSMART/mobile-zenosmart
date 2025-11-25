import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../repositories/device_repository.dart';

class DeviceNamePage extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic rxCharacteristic;
  final BluetoothCharacteristic txCharacteristic;
  final bool writeWithoutResponse;
  final String deviceDbId;
  final String deviceName;
  final String deviceUniqueId;

  const DeviceNamePage({
    super.key,
    required this.device,
    required this.rxCharacteristic,
    required this.txCharacteristic,
    required this.writeWithoutResponse,
    required this.deviceDbId,
    required this.deviceName,
    required this.deviceUniqueId,
  });

  @override
  State<DeviceNamePage> createState() => _DeviceNamePageState();
}

class _DeviceNamePageState extends State<DeviceNamePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isUpdating = false;
  bool _updateBluetoothName = true; // Default: Update in application and Bluetooth name

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.deviceName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _sendAtCommand(String command) async {
    try {
      final commandBytes = command.codeUnits;
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
      // Komutun işlenmesi için kısa bir bekleme
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('AT komutu gönderme hatası: $e');
      rethrow;
    }
  }

  Future<void> _reconnectDevice() async {
    try {
      // Mevcut bağlantıyı kes
      await widget.device.disconnect();
      await Future.delayed(const Duration(milliseconds: 1000));

      // Yeni isimle tekrar bağlan (kullanıcı fark etmeden)
      final newDevice = BluetoothDevice.fromId(widget.deviceUniqueId);
      await newDevice.connect(timeout: const Duration(seconds: 10));
      await Future.delayed(const Duration(milliseconds: 500));

      // Servisleri keşfet
      await newDevice.discoverServices();
      
      debugPrint('✅ Cihaza yeni isimle yeniden bağlanıldı');
    } catch (e) {
      debugPrint('⚠️ Cihaza yeniden bağlanma hatası: $e');
      // Hata olsa bile devam et, çünkü isim değişti
    }
  }

  Future<void> _updateDeviceName() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      // 1. Veritabanını güncelle
      await const DeviceRepository().updateName(widget.deviceDbId, newName);

      // 2. Eğer Bluetooth ismi de değiştirilecekse
      if (_updateBluetoothName) {
        // AT+NAME komutunu gönder
        final atCommand = 'AT+NAME=$newName\r\n';
        await _sendAtCommand(atCommand);

        // Cihaza tekrar bağlan (kullanıcı fark etmeden)
        await _reconnectDevice();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device name updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Modal'ı kapat ve geri dön
        Navigator.of(context).pop(true); // true = başarılı güncelleme
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating device name: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Change Device Name',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Device Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Device name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Update options
              Row(
                children: [
                  Checkbox(
                    value: !_updateBluetoothName,
                    onChanged: (value) {
                      setState(() {
                        _updateBluetoothName = false;
                      });
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Update only in application',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                    value: _updateBluetoothName,
                    onChanged: (value) {
                      setState(() {
                        _updateBluetoothName = true;
                      });
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Update in application and Bluetooth name',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isUpdating
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isUpdating ? null : _updateDeviceName,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008E46),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Update'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

