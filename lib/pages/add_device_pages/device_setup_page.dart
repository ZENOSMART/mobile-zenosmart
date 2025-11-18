import 'package:flutter/material.dart';
import '../../services/device_setup_service.dart';
import '../add_device_form_page.dart';

class DeviceSetupPage extends StatefulWidget {
  final AddDeviceDraft draft;
  final VoidCallback onSetupComplete;
  final VoidCallback onRetry;

  const DeviceSetupPage({
    super.key,
    required this.draft,
    required this.onSetupComplete,
    required this.onRetry,
  });

  @override
  State<DeviceSetupPage> createState() => _DeviceSetupPageState();
}

class _DeviceSetupPageState extends State<DeviceSetupPage> {
  final _deviceSetupService = const DeviceSetupService();
  bool _isChecking = false;
  String _errorMessage = '';
  bool _isCompleted = false;
  bool _processStarted = false;
  bool _configDeploySent = false;
  int _configDeployAttempt = 0; // Add this to track config deploy attempts

  @override
  void initState() {
    super.initState();
    // İlk olarak orderCode kontrolü yapılır
    // _checkOrderCode(); // Bu satırı kaldırıyoruz, butona basıldığında çalışacak
  }

  Future<void> _startProcess() async {
    setState(() {
      _processStarted = true;
    });
    _checkOrderCode();
  }

  Future<void> _checkOrderCode() async {
    setState(() {
      _isChecking = true;
      _errorMessage = '';
      _isCompleted = false;
      _configDeploySent = false;
    });

    try {
      // Önce orderCode kontrolü yapılır
      await _deviceSetupService.ensureDeviceTypeModel(widget.draft.orderCode);

      // Eğer başarılıysa cihaz kurulumunu yap
      await _setupDevice();
    } catch (e) {
      String userFriendlyMessage = 'An unknown error occurred';

      // Make error message user-friendly
      if (e is Exception) {
        String errorMessage = e.toString();

        // Make API error messages more descriptive
        if (errorMessage.contains('API hatası')) {
          userFriendlyMessage =
              'Unable to reach the server at this time. Please try again later.';
        }
        // Internet connection error
        else if (errorMessage.contains('SocketException') ||
            errorMessage.contains('Connection refused') ||
            errorMessage.contains('Network')) {
          userFriendlyMessage =
              'Internet connection not found. Please check your connection.';
        }
        // OrderCode not found error
        else if (errorMessage.contains('Order Code için model bulunamadı')) {
          userFriendlyMessage =
              'Invalid Order Code. Please make sure you are using the correct Order Code.';
        }
        // Other errors
        else {
          userFriendlyMessage =
              'An error occurred during the process. Please try again later.';
        }
      }

      if (mounted) {
        setState(() {
          _errorMessage = userFriendlyMessage;
          _isChecking = false;
          _isCompleted = false;
          _processStarted = false; // Reset process started state on error
        });
      }
    }
  }

  Future<void> _setupDevice() async {
    try {
      // Cihaz kurulumunu yap
      await _deviceSetupService.setupDevice(
        uniqueKey: widget.draft.uniqueKey,
        name: widget.draft.name,
        orderCode: widget.draft.orderCode,
        devEui: widget.draft.devEui,
        joinEui: widget.draft.joinEui,
        latitude: widget.draft.latitude!,
        longitude: widget.draft.longitude!,
        location: widget.draft.location,
        deviceType: widget.draft.deviceType,
        deviceAddr: widget.draft.deviceAddr,
        renameDevice: true,
      );

      // Cihaz kurulumu tamamlandı, şimdi config deploy gönder
      await _sendConfigDeploy();
    } catch (e) {
      String userFriendlyMessage = 'An unknown error occurred';

      // Make error message user-friendly
      if (e is Exception) {
        String errorMessage = e.toString();

        // Make API error messages more descriptive
        if (errorMessage.contains('API hatası')) {
          userFriendlyMessage =
              'Unable to reach the server at this time. Please try again later.';
        }
        // Internet connection error
        else if (errorMessage.contains('SocketException') ||
            errorMessage.contains('Connection refused') ||
            errorMessage.contains('Network')) {
          userFriendlyMessage =
              'Internet connection not found. Please check your connection.';
        }
        // Database error
        else if (errorMessage.contains('DatabaseException') ||
            errorMessage.contains('database')) {
          userFriendlyMessage =
              'A database error occurred. Please try again later.';
        }
        // Other errors
        else {
          userFriendlyMessage =
              'An error occurred during device setup. Please try again later.';
        }
      }

      if (mounted) {
        setState(() {
          _errorMessage = userFriendlyMessage;
          _isChecking = false;
          _isCompleted = false;
          _processStarted = false; // Reset process started state on error
        });
      }
    }
  }

  Future<void> _sendConfigDeploy() async {
    try {
      // Config deploy verisini gönder (3 kez denenecek)
      final result = await _deviceSetupService.sendConfigDeploy(
        uniqueKey: widget.draft.uniqueKey,
        latitude: widget.draft.latitude!,
        longitude: widget.draft.longitude!,
        onAttempt: (attempt) {
          // Deneme sayısını UI'ye bildir
          if (mounted) {
            setState(() {
              _configDeployAttempt = attempt;
            });
          }
        },
      );

      if (result) {
        // Config deploy başarılı
        if (mounted) {
          setState(() {
            _isChecking = false;
            _isCompleted = true;
            _configDeploySent = true;
            _configDeployAttempt = 0; // Başarılı olunca sıfırla
          });
        }
      } else {
        // Config deploy başarısız
        if (mounted) {
          setState(() {
            _errorMessage =
                'Config deploy could not be sent. Please try again later.';
            _isChecking = false;
            _isCompleted = false;
            _processStarted = false;
            _configDeploySent = false;
            _configDeployAttempt = 0; // Reset on error
          });
        }
      }
    } catch (e) {
      String userFriendlyMessage = 'An unknown error occurred';

      // Make error message user-friendly
      if (e is Exception) {
        String errorMessage = e.toString();

        // Bluetooth connection error
        if (errorMessage.contains('Bluetooth')) {
          userFriendlyMessage =
              'Bluetooth connection could not be established. Please make sure you are near the device and Bluetooth is enabled.';
        }
        // Other errors
        else {
          userFriendlyMessage =
              'An error occurred while sending config deploy. Please try again later.';
        }
      }

      if (mounted) {
        setState(() {
          _errorMessage = userFriendlyMessage;
          _isChecking = false;
          _isCompleted = false;
          _processStarted = false;
          _configDeploySent = false;
          _configDeployAttempt = 0; // Hata olunca sıfırla
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
            if (!_processStarted) ...[
              // Initial state with save button
              const Icon(Icons.settings, color: Color(0xFF008E46), size: 64),
              const SizedBox(height: 24),
              const Text(
                'Device Setup',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Press the "Save" button to load device configurations',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _startProcess,
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
                child: const Text('Save'),
              ),
            ] else if (_isChecking && !_configDeploySent) ...[
              Image.asset(
                'assets/icons/zenopix-favikon.gif',
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 24),
              const Text(
                'Loading Device Configurations',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please wait...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ] else if (_isChecking && _configDeploySent) ...[
              Image.asset(
                'assets/icons/zenopix-favikon.gif',
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 24),
              const Text(
                'Sending Config Deploy',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _configDeployAttempt > 0
                    ? 'Attempt: $_configDeployAttempt/3'
                    : 'Please wait...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ] else if (_errorMessage.isNotEmpty) ...[
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
                onPressed: _startProcess,
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
            ] else if (_isCompleted) ...[
              const Icon(
                Icons.check_circle,
                color: Color(0xFF008E46),
                size: 64,
              ),
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
                'Device has been successfully configured',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: widget.onSetupComplete,
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
                child: const Text('Continue'),
              ),
            ] else ...[
              // Empty state or initial state
              Container(),
            ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
