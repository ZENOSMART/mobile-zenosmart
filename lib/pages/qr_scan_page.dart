import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  bool _handled = false;
  bool _hasPermission = false;
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    if (Platform.isIOS || Platform.isAndroid) {
      final status = await Permission.camera.status;
      if (status.isDenied) {
        final result = await Permission.camera.request();
        if (mounted) {
          setState(() {
            _hasPermission = result.isGranted;
            _permissionChecked = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasPermission = status.isGranted;
            _permissionChecked = true;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _hasPermission = true;
          _permissionChecked = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/zenosmart-logo.png',
          height: 22,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
      ),
      body: _permissionChecked && !_hasPermission
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera Permission Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This app needs camera access to scan QR codes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        await _checkCameraPermission();
                        if (!_hasPermission && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enable camera permission in Settings.',
                              ),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      child: const Text('Grant Permission'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    if (_handled || !_hasPermission) return;
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final raw = barcodes.first.rawValue;
                    if (raw == null || raw.isEmpty) return;
                    _handled = true;
                    Navigator.of(context).pop<String>(raw);
                  },
                ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Scan the QR code',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
