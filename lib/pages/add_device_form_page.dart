import 'package:flutter/material.dart';
import 'add_device_pages/device_info_page.dart';
import 'devices_page.dart';

class AddDeviceDraft {
  AddDeviceDraft({required this.uniqueKey});

  final String uniqueKey;
  String name = '';
  String location = '';
  double? latitude;
  double? longitude;
  String devEui = '';
  String joinEui = '';
  String deviceAddr = '';
  String orderCode = '';
  String? deviceType;
}

class AddDeviceFormPage extends StatefulWidget {
  const AddDeviceFormPage({
    super.key,
    required this.uniqueKey,
    this.initialName,
    this.initialDeviceType,
  });

  final String uniqueKey;
  final String? initialName;
  final String? initialDeviceType;

  @override
  State<AddDeviceFormPage> createState() => _AddDeviceFormPageState();
}

class _AddDeviceFormPageState extends State<AddDeviceFormPage> {
  late AddDeviceDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = AddDeviceDraft(uniqueKey: widget.uniqueKey)
      ..deviceType = widget.initialDeviceType;
    if (widget.initialName != null) {
      _draft.name = widget.initialName!.trim();
    }
  }

  void _updateDraft(AddDeviceDraft updatedDraft) {
    setState(() {
      _draft = updatedDraft;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Image.asset(
          'assets/images/zenosmart-logo.png',
          height: 22,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildCurrentStepHeader(),
            const Divider(height: 1),
            // Page content
            Expanded(
              child: DeviceInfoPage(
                draft: _draft,
                onDraftUpdated: _updateDraft,
                onSetupComplete: () async {
                  // Setup completed, navigate back to Devices Page
                  if (mounted) {
                    // Tüm ekleme sayfalarını kapat ve Devices Page'e dön
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const DevicesPage()),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepHeader() {
    const stepTitle = 'Device Information';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF008E46),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '1',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            stepTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
