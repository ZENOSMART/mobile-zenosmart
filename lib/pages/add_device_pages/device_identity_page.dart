import 'package:flutter/material.dart';
import '../add_device_form_page.dart';
import '../../utils/qr_parser_util.dart';
import '../qr_scan_page.dart';

class DeviceIdentityPage extends StatefulWidget {
  const DeviceIdentityPage({
    super.key,
    required this.draft,
    required this.onDraftUpdated,
  });

  final AddDeviceDraft draft;
  final Function(AddDeviceDraft) onDraftUpdated;

  @override
  State<DeviceIdentityPage> createState() => _DeviceIdentityPageState();
}

class _DeviceIdentityPageState extends State<DeviceIdentityPage> {
  static const _accentColor = Color(0xFF008E46);
  static const _fieldHeight = 56.0;
  static const _fieldLabelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );
  late TextEditingController _devEuiController;
  late TextEditingController _joinEuiController;
  late TextEditingController _deviceAddrController;
  late TextEditingController _orderCodeController;

  @override
  void initState() {
    super.initState();
    _devEuiController = TextEditingController(text: widget.draft.devEui);
    _joinEuiController = TextEditingController(text: widget.draft.joinEui);
    _deviceAddrController = TextEditingController(
      text: widget.draft.deviceAddr,
    );
    _orderCodeController = TextEditingController(text: widget.draft.orderCode);
  }

  @override
  void dispose() {
    _devEuiController.dispose();
    _joinEuiController.dispose();
    _deviceAddrController.dispose();
    _orderCodeController.dispose();
    super.dispose();
  }

  void _updateDraft() {
    final draft = widget.draft
      ..devEui = _devEuiController.text.trim()
      ..joinEui = _joinEuiController.text.trim()
      ..deviceAddr = _deviceAddrController.text.trim()
      ..orderCode = _orderCodeController.text.trim();
    widget.onDraftUpdated(draft);
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
    final orderCode = QrParserUtil.extractOrderCode(qrData);

    if (devEui != null) _devEuiController.text = devEui;
    if (joinEui != null) _joinEuiController.text = joinEui;
    if (devAddr != null) _deviceAddrController.text = devAddr;
    if (orderCode != null) _orderCodeController.text = orderCode;
    _updateDraft();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _buildTextField(
            label: 'DevEUI',
            controller: _devEuiController,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'DevEUI required' : null,
            onChanged: (_) => _updateDraft(),
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'JoinEUI',
            controller: _joinEuiController,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'JoinEUI required' : null,
            onChanged: (_) => _updateDraft(),
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'DeviceAddr (optional)',
            controller: _deviceAddrController,
            onChanged: (_) => _updateDraft(),
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Order Code',
            controller: _orderCodeController,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Order Code required' : null,
            onChanged: (_) => _updateDraft(),
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
                textStyle: const TextStyle(fontSize: 16),
              ),
              onPressed: _scanQr,
              icon: const Icon(Icons.qr_code_scanner, size: 22),
              label: const Text('Read QR Code'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool readOnly = false,
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
            validator: validator,
            onChanged: onChanged,
            readOnly: readOnly,
            decoration: _buildInputDecoration(hintText: hintText),
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
