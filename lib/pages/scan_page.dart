import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/device_type.dart';
import 'add_device_form_page.dart';
import '../repositories/device_repository.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, this.deviceType});

  final DeviceType? deviceType;
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  StreamSubscription<List<ScanResult>>? _scanSub;
  List<ScanResult> _results = const [];
  bool _isScanning = false;
  StreamSubscription<bool>? _isScanningSub;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSub;
  DeviceType? _selectedDeviceType;
  Set<String> _existingKeys = {};
  bool _isBluetoothDialogShowing = false;
  BluetoothAdapterState? _lastAdapterState;

  @override
  void initState() {
    super.initState();
    _selectedDeviceType = widget.deviceType;
    // Bluetooth durumunu dinle
    _adapterStateSub = FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;
      _lastAdapterState = state;
      
      // iOS'ta bazen geçici durum değişiklikleri olabilir, bir süre bekle
      if (state != BluetoothAdapterState.on) {
        // Eğer dialog zaten açıksa tekrar açma
        if (!_isBluetoothDialogShowing) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _lastAdapterState != BluetoothAdapterState.on) {
              _showBluetoothOffDialog();
            }
          });
        }
      } else {
        // Bluetooth açıldıysa dialog'u kapat
        if (_isBluetoothDialogShowing) {
          Navigator.of(context).pop();
          _isBluetoothDialogShowing = false;
        }
        // Eğer tarama yapılmıyorsa başlat
        if (!_isScanning) {
          _startScan();
        }
      }
    });
    // Sayfa açıldığında Bluetooth kontrolü ve otomatik tarama
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Önce izinleri kontrol et
      if (await _ensurePermissions()) {
        // iOS'ta durumu birkaç kez kontrol et
        BluetoothAdapterState? adapterState;
        for (int i = 0; i < 3; i++) {
          adapterState = await FlutterBluePlus.adapterState.first;
          if (adapterState == BluetoothAdapterState.on) break;
          await Future.delayed(const Duration(milliseconds: 300));
        }
        
        if (adapterState == BluetoothAdapterState.on) {
          await _startScan();
        } else if (adapterState != BluetoothAdapterState.unauthorized) {
          // Unauthorized durumunda zaten _ensurePermissions mesaj gösterdi
          _showBluetoothOffDialog();
        }
      }
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    _adapterStateSub?.cancel();
    super.dispose();
  }

  void _showBluetoothOffDialog() {
    if (!mounted || _isBluetoothDialogShowing) return;
    
    _isBluetoothDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.red),
            SizedBox(width: 8),
            Text('Bluetooth Off'),
          ],
        ),
        content: const Text(
          'You need to turn on Bluetooth to scan for Bluetooth devices.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _isBluetoothDialogShowing = false;
            },
            child: const Text('OK'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008E46),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              _isBluetoothDialogShowing = false;
              // Bluetooth'u açmayı dene
              try {
                if (Platform.isAndroid) {
                  await FlutterBluePlus.turnOn();
                } else if (Platform.isIOS) {
                  // iOS'ta Bluetooth'u programatik olarak açamayız
                  // Kullanıcıya ayarlara yönlendir
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please turn on Bluetooth from Settings > Bluetooth',
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                }
              } catch (e) {
                // Bazı cihazlarda otomatik açma desteklenmeyebilir
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please turn on Bluetooth manually from settings.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Turn On Bluetooth'),
          ),
        ],
      ),
    ).then((_) {
      _isBluetoothDialogShowing = false;
    });
  }

  Future<bool> _ensurePermissions() async {
    if (Platform.isAndroid) {
      final req = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
      final ok = req.values.every((s) => s.isGranted);
      return ok;
    } else if (Platform.isIOS) {
      // iOS'ta Bluetooth izinleri otomatik olarak istenir (Info.plist'te tanımlı)
      // iOS'ta Bluetooth durumunu kontrol et
      try {
        final adapterState = await FlutterBluePlus.adapterState.first;
        // iOS'ta adapterState.unauthorized durumu izin reddedildiğinde olabilir
        if (adapterState == BluetoothAdapterState.unauthorized) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Bluetooth permission is required. Please enable it in Settings.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
          }
          return false;
        }
        
        // iOS'ta Bluetooth scan için konum izni de gerekebilir (iOS 13+)
        final locationStatus = await Permission.locationWhenInUse.status;
        if (locationStatus.isDenied) {
          final locationResult = await Permission.locationWhenInUse.request();
          if (!locationResult.isGranted && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Location permission is required for Bluetooth scanning on iOS.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
            return false;
          }
        }
        
        return adapterState == BluetoothAdapterState.on;
      } catch (e) {
        // Hata durumunda false döndür
        return false;
      }
    }
    return true;
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    // Önce izinleri kontrol et (iOS'ta da durum kontrolü yapar)
    if (!await _ensurePermissions()) {
      if (mounted && !_isBluetoothDialogShowing) {
        // iOS'ta unauthorized durumu için özel mesaj
        final adapterState = await FlutterBluePlus.adapterState.first;
        if (adapterState == BluetoothAdapterState.unauthorized) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bluetooth permission denied. Please enable it in Settings > Privacy & Security > Bluetooth.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          _showBluetoothOffDialog();
        }
      }
      return;
    }

    // Bluetooth durumunu kontrol et - iOS'ta birkaç kez kontrol et
    BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
    
    // iOS'ta bazen ilk kontrol yanlış olabilir, birkaç kez dene
    if (Platform.isIOS && adapterState != BluetoothAdapterState.on) {
      for (int i = 0; i < 2; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        adapterState = await FlutterBluePlus.adapterState.first;
        if (adapterState == BluetoothAdapterState.on) break;
      }
    }
    
    if (adapterState != BluetoothAdapterState.on) {
      if (!_isBluetoothDialogShowing) {
        _showBluetoothOffDialog();
      }
      return;
    }

    _isScanningSub?.cancel();
    _isScanningSub = FlutterBluePlus.isScanning.listen((v) {
      if (mounted) setState(() => _isScanning = v);
    });

    if (mounted) setState(() => _isScanning = true);
    // Mevcut kayıtlı cihaz anahtarlarını yükle
    try {
      _existingKeys = await const DeviceRepository().listAllUniqueKeys();
    } catch (_) {
      _existingKeys = {};
    }
    _scanSub = FlutterBluePlus.scanResults.listen((list) {
      if (!mounted) return;
      setState(() {
        _results = list.where((result) {
          final remoteId = result.device.remoteId.str;
          if (_existingKeys.contains(remoteId)) {
            return false; // Zaten kayıtlı olanları gösterme
          }
          final advertisedUuids = result.advertisementData.serviceUuids
              .map((g) => g.str.toUpperCase())
              .toList();

          final matchedType = _findMatchedType(advertisedUuids);
          if (matchedType == null) return false;

          if (_selectedDeviceType != null) {
            return matchedType.serialId == _selectedDeviceType!.serialId;
          }
          return true;
        }).toList();
      });
    });
    try {
      await FlutterBluePlus.startScan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan could not be started: $e')));
      }
    }
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
    setState(() => _isScanning = false);
  }

  DeviceType? _findMatchedType(List<String> advertisedUuids) {
    for (final type in DeviceType.values) {
      if (DeviceType.matchesByServiceUuid(
        targetUuid: type.serialId,
        advertisedServiceUuids: advertisedUuids,
      )) {
        return type;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Device'),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.refresh),
            onPressed: _isScanning ? _stopScan : _startScan,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDeviceType?.displayName ??
                        'All supported devices',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        _isScanning ? Icons.wifi_tethering : Icons.pause,
                        size: 18,
                        color: const Color(0xFF008E46),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _isScanning
                              ? 'Scanning in progress...'
                              : 'Scan stopped. Use the button in the top right to refresh.',
                          style: TextStyle(
                            fontSize: 13,
                            color: _isScanning
                                ? const Color(0xFF008E46)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final r = _results[index];
                final name = r.advertisementData.advName.isNotEmpty
                    ? r.advertisementData.advName
                    : r.device.platformName.isNotEmpty
                    ? r.device.platformName
                    : r.device.remoteId.str;
                final advertisedUuids = r.advertisementData.serviceUuids
                    .map((g) => g.str.toUpperCase())
                    .toList();

                // Cihaz tipini bul
                final matchedType = _findMatchedType(advertisedUuids);

                final macAddress = r.device.remoteId.str;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (macAddress.isNotEmpty)
                          Text(
                            macAddress,
                            style: const TextStyle(fontSize: 13),
                          ),
                        Text(
                          'RSSI: ${r.rssi}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF1E325A),
                    ),
                    onTap: () async {
                      await _stopScan();
                      if (!mounted) return;
                      final saved = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddDeviceFormPage(
                            uniqueKey: r.device.remoteId.str,
                            initialName: name,
                            initialDeviceType: matchedType?.serialId,
                          ),
                        ),
                      );
                      if (!mounted) return;
                      if (saved == true) {
                        Navigator.of(context).pop(true);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
