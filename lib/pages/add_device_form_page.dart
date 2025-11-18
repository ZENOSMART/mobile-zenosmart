import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/device_setup_service.dart';
import 'add_device_pages/device_info_page.dart';
import 'add_device_pages/device_identity_page.dart';
import 'add_device_pages/device_setup_page.dart';

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
  final PageController _pageController = PageController();
  static const int _totalPages = 3;
  final _deviceSetupService = const DeviceSetupService();
  bool _saving = false;
  int _currentPage = 0;
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

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    }
  }

  Future<void> _save() async {
    if (_draft.latitude == null ||
        _draft.longitude == null ||
        _draft.location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location (latitude/longitude/location) is required.'),
        ),
      );
      return;
    }

    final orderCode = _draft.orderCode;
    if (orderCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order Code is required (scan with QR)')),
      );
      return;
    }

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

    // Instead of showing loading dialog and performing setup directly,
    // we navigate to the setup page
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                physics:
                    const NeverScrollableScrollPhysics(), // Yana kaydırmayı devre dışı bırak
                children: [
                  DeviceInfoPage(draft: _draft, onDraftUpdated: _updateDraft),
                  DeviceIdentityPage(draft: _draft, onDraftUpdated: _updateDraft),
                  DeviceSetupPage(
                    draft: _draft,
                    onSetupComplete: () {
                      // Setup completed, close the form
                      if (mounted) Navigator.of(context).pop(true);
                    },
                    onRetry: () {
                      // Go back to the previous page to retry
                      if (mounted) {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Navigation buttons - Fixed at bottom
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                20,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIconNavigationButton(
                    icon: Icons.chevron_left,
                    onTap: _currentPage > 0 && !_saving
                        ? () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                  ),
                  const SizedBox(width: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF008E46),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentPage + 1} / $_totalPages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  if (_saving)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF008E46).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF008E46),
                          ),
                        ),
                      ),
                    )
                  else
                    _buildIconNavigationButton(
                      icon: Icons.chevron_right,
                      onTap: _saving
                          ? null
                          : () {
                              if (_currentPage == _totalPages - 1) {
                                _save();
                              } else {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepHeader() {
    const stepTitles = [
      'Device Information',
      'Identity Information',
      'Device Setup',
    ];
    final stepTitle = stepTitles[_currentPage];
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
            child: Center(
              child: Text(
                '${_currentPage + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            stepTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconNavigationButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isEnabled
              ? const Color(0xFF008E46)
              : const Color(0xFF008E46).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isEnabled ? Colors.white : const Color(0xFF008E46),
        ),
      ),
    );
  }
}
