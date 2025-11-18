import 'package:flutter/material.dart';
import '../models/device_type.dart';
import 'scan_page.dart';

class DeviceTypePage extends StatefulWidget {
  const DeviceTypePage({super.key});

  @override
  State<DeviceTypePage> createState() => _DeviceTypePageState();
}

class _DeviceTypePageState extends State<DeviceTypePage> {
  Future<void> _handleTypeTap(DeviceType type) async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => ScanPage(deviceType: type)));
    if (!mounted) return;
    if (result == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceTypes = DeviceType.values;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Device Type')),
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemBuilder: (context, index) {
          final type = deviceTypes[index];
          return _DeviceTypeCard(type: type, onTap: () => _handleTypeTap(type));
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: deviceTypes.length,
      ),
    );
  }
}

class _DeviceTypeCard extends StatelessWidget {
  const _DeviceTypeCard({required this.type, required this.onTap});

  final DeviceType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                type.imageAssetPath,
                width: 96,
                height: 96,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 96,
                    height: 96,
                    color: Colors.grey.shade200,
                    child: Icon(
                      type.icon,
                      color: const Color(0xFF008E46),
                      size: 40,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Service UUID: ${type.serialId}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF1E325A)),
          ],
        ),
      ),
    );
  }
}
