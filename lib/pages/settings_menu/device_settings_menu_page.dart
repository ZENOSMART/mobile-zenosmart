import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'device_config_settings_page.dart';
import 'device_general_settings_page.dart';
import 'device_identity_settings_page.dart';
import 'device_firmware_info_settings_page.dart';
import 'device_card_settings_page.dart';
import '../firmware_update_page.dart';

class DeviceSettingsMenuPage extends StatelessWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic rxCharacteristic;
  final BluetoothCharacteristic txCharacteristic;
  final bool writeWithoutResponse;
  final String deviceDbId;
  final String deviceName;

  const DeviceSettingsMenuPage({
    super.key,
    required this.device,
    required this.rxCharacteristic,
    required this.txCharacteristic,
    required this.writeWithoutResponse,
    required this.deviceDbId,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(title: Text(deviceName), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsItem(
            context: context,
            icon: Icons.map,
            title: 'Config and Time Settings',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeviceConfigSettingsPage(
                    device: device,
                    rxCharacteristic: rxCharacteristic,
                    txCharacteristic: txCharacteristic,
                    writeWithoutResponse: writeWithoutResponse,
                    deviceDbId: deviceDbId,
                    deviceName: deviceName,
                  ),
                ),
              );
            },
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.tune,
            title: 'General Settings',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeviceGeneralSettingsPage(
                    device: device,
                    rxCharacteristic: rxCharacteristic,
                    txCharacteristic: txCharacteristic,
                    writeWithoutResponse: writeWithoutResponse,
                    deviceDbId: deviceDbId,
                    deviceName: deviceName,
                  ),
                ),
              );
            },
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.link,
            title: 'Connection Settings',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeviceIdentitySettingsPage(
                    device: device,
                    rxCharacteristic: rxCharacteristic,
                    txCharacteristic: txCharacteristic,
                    writeWithoutResponse: writeWithoutResponse,
                    deviceDbId: deviceDbId,
                    deviceName: deviceName,
                  ),
                ),
              );
            },
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.info,
            title: 'Firmware Info Settings',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeviceFirmwareInfoSettingsPage(
                    device: device,
                    rxCharacteristic: rxCharacteristic,
                    txCharacteristic: txCharacteristic,
                    writeWithoutResponse: writeWithoutResponse,
                    deviceDbId: deviceDbId,
                    deviceName: deviceName,
                  ),
                ),
              );
            },
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.system_update,
            title: 'Firmware Update',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FirmwareUpdatePage(
                    deviceId: deviceDbId,
                    deviceName: deviceName,
                    rxCharacteristic: rxCharacteristic,
                    txCharacteristic: txCharacteristic,
                    project: '',
                    hwVersion: '',
                  ),
                ),
              );
            },
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.settings_applications,
            title: 'Device Reset/Clear',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeviceCardSettingsPage(
                    device: device,
                    rxCharacteristic: rxCharacteristic,
                    txCharacteristic: txCharacteristic,
                    writeWithoutResponse: writeWithoutResponse,
                    deviceDbId: deviceDbId,
                    deviceName: deviceName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Icon(icon, size: 32, color: const Color(0xFF008e46)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
