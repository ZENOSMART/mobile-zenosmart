import 'package:flutter/material.dart';
import '../add_device_form_page.dart';
import '../../services/device_setup_service.dart';
import '../../models/device_type.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DeviceInfoPage extends StatefulWidget {
  const DeviceInfoPage({
    super.key,
    required this.draft,
    required this.onDraftUpdated,
    required this.onSetupComplete,
  });

  final AddDeviceDraft draft;
  final Function(AddDeviceDraft) onDraftUpdated;
  final VoidCallback onSetupComplete;

  @override
  State<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage> {
  static const _accentColor = Color(0xFF008E46);
  static const _fieldHeight = 56.0;
  static const _fieldLabelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );
  late TextEditingController _nameController;
  final _deviceSetupService = const DeviceSetupService();
  bool _isProcessing = false;
  bool _isCompleted = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _currentStep = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draft.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _updateDraft() {
    final draft = widget.draft..name = _nameController.text.trim();
    widget.onDraftUpdated(draft);
  }

  String _getStepTitle() {
    if (_currentStep.isEmpty) {
      return 'Processing...';
    }
    if (_currentStep.contains('Order Code')) {
      return 'Checking Order Code';
    }
    if (_currentStep.contains('Bluetooth')) {
      return 'Connecting to Device';
    }
    if (_currentStep.contains('Cihaz Kaydediliyor')) {
      return 'Saving Device';
    }
    return 'Processing...';
  }

  Future<void> _save() async {
    // Name kontrolü
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Device name is required.')));
      return;
    }

    // Device type kontrolü
    if (widget.draft.deviceType == null || widget.draft.deviceType!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Device type is required.')));
      return;
    }

    // OrderCode'u device type'dan al
    final deviceType = DeviceType.findBySerialId(widget.draft.deviceType!);
    if (deviceType == null || deviceType.orderCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order Code not found for this device type.'),
        ),
      );
      return;
    }
    widget.draft.orderCode = deviceType.orderCode!;
    widget.draft.name = _nameController.text.trim();
    _updateDraft();

    // Internet kontrolü
    final connectivity = await Connectivity().checkConnectivity();
    final hasNetwork = connectivity != ConnectivityResult.none;
    if (!hasNetwork) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Internet connection not found. Please check your connection.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _hasError = false;
      _isCompleted = false;
      _errorMessage = '';
      _currentStep = '';
    });

    try {
      final result = await _deviceSetupService.setupDeviceComplete(
        uniqueKey: widget.draft.uniqueKey,
        name: widget.draft.name,
        orderCode: widget.draft.orderCode,
        devEui: widget.draft.devEui,
        joinEui: widget.draft.joinEui,
        latitude: widget.draft.latitude ?? 0.0,
        longitude: widget.draft.longitude ?? 0.0,
        location: widget.draft.location,
        deviceType: widget.draft.deviceType,
        deviceAddr: widget.draft.deviceAddr,
        renameDevice: true,
        onStepUpdate: (step) {
          if (mounted) {
            setState(() {
              _currentStep = step;
            });
          }
        },
      );

      if (result.success) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _isCompleted = true;
          });
          // Kısa bir süre sonra kapat
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              widget.onSetupComplete();
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _hasError = true;
            _errorMessage = 'Device setup failed.';
          });
        }
      }
    } catch (e) {
      String userFriendlyMessage = 'An unknown error occurred';

      if (e is Exception) {
        String errorMessage = e.toString();

        if (errorMessage.contains('API hatası')) {
          userFriendlyMessage =
              'Unable to reach the server at this time. Please try again later.';
        } else if (errorMessage.contains('SocketException') ||
            errorMessage.contains('Connection refused') ||
            errorMessage.contains('Network')) {
          userFriendlyMessage =
              'Internet connection not found. Please check your connection.';
        } else if (errorMessage.contains('Order Code için model bulunamadı')) {
          userFriendlyMessage =
              'Invalid Order Code. Please make sure you are using the correct Order Code.';
        } else {
          userFriendlyMessage =
              'An error occurred during the process. Please try again later.';
        }
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _hasError = true;
          _errorMessage = userFriendlyMessage;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/zenopix-favikon.gif',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 24),
            Text(
              _getStepTitle(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentStep.isNotEmpty ? _currentStep : 'Please wait...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_isCompleted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF008E46), size: 64),
            const SizedBox(height: 24),
            const Text(
              'Setup Completed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Device has been successfully saved',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Operation Failed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _errorMessage = '';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008E46),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _buildTextField(
            controller: _nameController,
            label: 'Device Name',
            onChanged: (_) => _updateDraft(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: _fieldHeight,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? hintText,
    void Function(String)? onChanged,
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
            keyboardType: keyboardType,
            decoration: _buildInputDecoration(hintText: hintText),
            onChanged: onChanged,
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
