import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../bluetooth_device_update/bluetooth_device_update.dart';

class FirmwareUpdatePage extends StatefulWidget {
  const FirmwareUpdatePage({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.rxCharacteristic,
    required this.txCharacteristic,
    required this.project,
    required this.hwVersion,
  });

  final String deviceId;
  final String deviceName;
  final BluetoothCharacteristic rxCharacteristic;
  final BluetoothCharacteristic txCharacteristic;
  final String project;
  final String hwVersion;

  @override
  State<FirmwareUpdatePage> createState() => _FirmwareUpdatePageState();
}

class _FirmwareUpdatePageState extends State<FirmwareUpdatePage> {
  late final UpdateManager _updateManager;
  StreamSubscription<UpdateEvent>? _eventSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  UpdateState _currentState = UpdateState.idle;
  UpdateInfo? _updateInfo;
  DeviceVersionInfo? _deviceVersionInfo;
  double _progress = 0.0;
  String _statusMessage = '';
  bool _startUpdateSent = false;
  bool _wasConnected = true;
  bool _connectionDialogShown = false;
  Timer? _restartPollingTimer;
  bool _restartCompletedDialogShown = false;

  @override
  void initState() {
    super.initState();
    _updateManager = UpdateManager();
    _setupEventListener();
    _setupConnectionListener();
    _initializeUpdate();
  }

  void _setupConnectionListener() {
    // Bluetooth cihaz bağlantı durumunu dinle
    final device = widget.rxCharacteristic.device;

    // Başlangıç durumunu kontrol et
    _wasConnected = device.isConnected;

    _connectionSubscription = device.connectionState.listen((state) {
      if (!mounted) return;

      if (state == BluetoothConnectionState.disconnected && _wasConnected) {
        // Bağlantı koptu
        _wasConnected = false;
        // Eğer waitingForRestart state'indeyse, bağlantı kesilmesi normal (cihaz restart oluyor)
        if (!_connectionDialogShown && _currentState != UpdateState.waitingForRestart) {
          _showConnectionLostDialog();
        }
      } else if (state == BluetoothConnectionState.connected) {
        _wasConnected = true;
        _connectionDialogShown =
            false; // Tekrar bağlandıysa dialog flag'ini sıfırla
        
        // Eğer waitingForRestart state'indeyse, cihaz tekrar bağlandığında versiyon isteği gönder
        if (_currentState == UpdateState.waitingForRestart) {
          _requestDeviceVersionForRestart();
        }
      }
    });
  }

  void _showConnectionLostDialog() {
    if (_connectionDialogShown) return; // Zaten gösterildiyse tekrar gösterme

    _connectionDialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.red),
            SizedBox(width: 8),
            Text('Connection Lost'),
          ],
        ),
        content: const Text(
          'Device connection lost. Please check the device and try reconnecting.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context); // Dialog'u kapat
              Navigator.pop(context); // Firmware update sayfasından çık
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _setupEventListener() {
    _eventSubscription = _updateManager.eventStream.listen((event) {
      if (!mounted) return;

      setState(() {
        if (event is UpdateStateChanged) {
          _currentState = event.state;
          _statusMessage = _getStateMessage(event.state);

          // Updating durumuna geçtiyse flag'i sıfırla
          if (event.state == UpdateState.updating) {
            _startUpdateSent = false;
          }

          // Versiyon bilgisi geldiyse güncelle
          if (_updateManager.deviceVersionInfo != null) {
            final newVersionInfo = _updateManager.deviceVersionInfo;
            // Eğer waitingForRestart state'indeyse ve versiyon bilgisi geldiyse
            if (_currentState == UpdateState.waitingForRestart && newVersionInfo != null && !_restartCompletedDialogShown) {
              _restartPollingTimer?.cancel();
              _restartPollingTimer = null;
              _deviceVersionInfo = newVersionInfo;
              _currentState = UpdateState.completed;
              _restartCompletedDialogShown = true;
              _showRestartCompletedDialog();
            } else {
              _deviceVersionInfo = newVersionInfo;
            }
          }
        } else if (event is UpdateProgressChanged) {
          _progress = event.progress.progress;
          _statusMessage =
              '${event.progress.partNum + 1}/${event.progress.totalChunks}';
        } else if (event is UpdateError) {
          _statusMessage = event.message;
          _showErrorDialog(event.message);
        } else if (event is UpdateCompleted) {
          _statusMessage = event.message;
          // Son paket gönderildikten 10 saniye sonra get version isteklerini başlat
          Future.delayed(const Duration(seconds: 10), () {
            if (mounted) {
              _startWaitingForRestart();
            }
          });
        }
      });
    });
  }

  String _getStateMessage(UpdateState state) {
    switch (state) {
      case UpdateState.idle:
        return 'Ready';
      case UpdateState.connecting:
        return 'Connecting to server...';
      case UpdateState.fetchingInfo:
        return 'Fetching firmware info...';
      case UpdateState.ready:
        return 'Update ready';
      case UpdateState.updating:
        return 'Updating...';
      case UpdateState.completed:
        return 'Update completed!';
      case UpdateState.waitingForRestart:
        return 'Device is restarting...';
      case UpdateState.failed:
        return 'Update failed';
    }
  }

  Future<void> _initializeUpdate() async {
    try {
      // Sunucuya bağlan
      await _updateManager.connectToServer(
        host: 'update.zenosmart.com',
        port: 80,
      );

      // BLE karakteristiğini ayarla
      await _updateManager.setupBleCharacteristic(widget.rxCharacteristic);

      // TX notification stream'ini bağla
      // NOT: device_detail_page'deki stream'i bozmamak için kendi stream'imizi oluştur
      debugPrint('[FirmwareUpdate] Setting up TX notification...');

      // Eğer notification kapalıysa aç
      if (!widget.txCharacteristic.isNotifying) {
        await widget.txCharacteristic.setNotifyValue(true);
        debugPrint('[FirmwareUpdate] TX notification enabled');
      }

      // onValueReceived kullan (lastValueStream yerine)
      _updateManager.attachNotificationStream(
        widget.txCharacteristic.onValueReceived,
      );
      debugPrint('[FirmwareUpdate] ✅ TX stream attached');

      // Cihazdan versiyon bilgisi iste
      await Future.delayed(const Duration(milliseconds: 500));
      await _requestDeviceVersion();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Start error: $e')));
      }
    }
  }

  Future<void> _requestDeviceVersion() async {
    try {
      await _updateManager.requestDeviceVersion();
      // Versiyon bilgisi geldikçe state güncellenecek
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _deviceVersionInfo = _updateManager.deviceVersionInfo;
        });
      }
    } catch (e) {
      debugPrint('Versiyon alma hatası: $e');
    }
  }

  Future<void> _fetchFirmwareInfo() async {
    // Version bilgisi olmalı
    if (_deviceVersionInfo == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Version information could not be retrieved from device. Please wait or refresh.',
            ),
          ),
        );
      }
      return;
    }

    // CİHAZDAN GELEN BİLGİLERLE sunucuya sor
    // FileState,FileSize otomatik olarak cihaza gönderilecek
    final info = await _updateManager.fetchFirmwareInfo(
      project: _deviceVersionInfo!.project ?? widget.project,
      hwVersion: _deviceVersionInfo!.hwVersion ?? widget.hwVersion,
    );

    if (mounted && info != null) {
      setState(() => _updateInfo = info);

      // Log: Hangi bilgilerle soruldu
      debugPrint(
        'Sunucuya soruldu: Project=${_deviceVersionInfo!.project}, HW=${_deviceVersionInfo!.hwVersion}',
      );
    }
  }

  Future<void> _startUpdate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            SizedBox(width: 8),
            Expanded(
              child: Text('Firmware Update', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: const Text(
          'Firmware update process will be started. '
          'Do not disconnect the device during the process. '
          'Do not leave the page during the process. '
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008E46),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _updateManager.startUpdate();
      setState(() {
        _startUpdateSent = true;
        _statusMessage =
            'START_UPDATE sent. Device will send chunk requests...';
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Hata'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _startWaitingForRestart() {
    if (!mounted) return;
    
    setState(() {
      _currentState = UpdateState.waitingForRestart;
      _statusMessage = 'Device is restarting...';
      _deviceVersionInfo = null; // Reset to detect when device responds
    });

    // Her 10 saniyede bir versiyon isteği gönder
    _restartPollingTimer?.cancel();
    _restartPollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _requestDeviceVersionForRestart();
    });

    // İlk isteği hemen gönder
    _requestDeviceVersionForRestart();
  }

  Future<void> _requestDeviceVersionForRestart() async {
    try {
      await _updateManager.requestDeviceVersion();
      // Versiyon bilgisi geldikçe state güncellenecek
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        final newVersionInfo = _updateManager.deviceVersionInfo;
        if (newVersionInfo != null && !_restartCompletedDialogShown) {
          // Cihaz cevap verdi, versiyon bilgisi geldi
          _restartPollingTimer?.cancel();
          _restartPollingTimer = null;
          
          setState(() {
            _deviceVersionInfo = newVersionInfo;
            _currentState = UpdateState.completed;
            _restartCompletedDialogShown = true;
          });
          
          _showRestartCompletedDialog();
        }
      }
    } catch (e) {
      debugPrint('Version request error during restart wait: $e');
    }
  }

  void _showRestartCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Update Completed'),
          ],
        ),
        content: const Text(
          'Firmware update completed successfully. '
          'Device has restarted and is ready.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _connectionSubscription?.cancel();
    _restartPollingTimer?.cancel();
    _updateManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firmware Update'),
        backgroundColor: const Color(0xFF1E325A),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF1F1F1),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Ana Durum Kartı (Büyük)
          if (_currentState == UpdateState.updating) _buildUpdatingCard(),
          if (_currentState == UpdateState.waitingForRestart) _buildRestartWaitingCard(),

          // Cihaz Bilgisi
          _buildDeviceInfoCard(),
          const SizedBox(height: 16),

          // Firmware Bilgisi ve İşlemler
          _buildFirmwareCard(),
          const SizedBox(height: 16),

          // Güncelleme Butonları
            _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildUpdatingCard() {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.system_update_alt,
              size: 64,
              color: Color(0xFF1E325A),
            ),
            const SizedBox(height: 16),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E325A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 12,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF008E46),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ Please do not disconnect the device',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestartWaitingCard() {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.restart_alt,
              size: 64,
              color: Color(0xFF1E325A),
            ),
            const SizedBox(height: 16),
            const Text(
              'Device Restarting',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E325A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFF008E46),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Waiting for device to respond...',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                const Text(
              'Device Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Divider(height: 24),
            if (_deviceVersionInfo != null) ...[
                    if (_deviceVersionInfo!.project != null) ...[
                _buildVersionInfoRow('Project', _deviceVersionInfo!.project!),
                      const SizedBox(height: 6),
                    ],
                    if (_deviceVersionInfo!.swVersion != null) ...[
                      _buildVersionInfoRow(
                  'SW Version',
                        _deviceVersionInfo!.swVersion!,
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (_deviceVersionInfo!.hwVersion != null)
                      _buildVersionInfoRow(
                  'HW Version',
                        _deviceVersionInfo!.hwVersion!,
                      ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey, width: 1),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Retrieving version information from device...',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _requestDeviceVersion,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildVersionInfoRow(String label, String value) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.blue,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFirmwareCard() {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                const Text(
              'Firmware Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Divider(height: 24),
            if (_updateInfo != null) ...[
              // Versiyon karşılaştırması
              if (_deviceVersionInfo?.swVersion != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  _deviceVersionInfo!.swVersion ?? '-',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward, color: Colors.grey),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'New',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  _updateInfo!.version ?? '-',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildInfoRow(
                Icons.storage,
                'File Size',
                '${(_updateInfo!.fileSize / 1024).toStringAsFixed(2)} KB',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _updateInfo!.isUpdateAvailable
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _updateInfo!.isUpdateAvailable
                        ? Colors.green
                        : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _updateInfo!.isUpdateAvailable
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: _updateInfo!.isUpdateAvailable
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _updateInfo!.isUpdateAvailable
                            ? 'Update Available ✓'
                            : 'No Update',
                        style: TextStyle(
                          color: _updateInfo!.isUpdateAvailable
                              ? Colors.green
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_download,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Firmware information not retrieved',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008E46),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed:
                    _deviceVersionInfo != null &&
                        (_currentState == UpdateState.idle ||
                        _currentState == UpdateState.ready ||
                            _currentState == UpdateState.fetchingInfo)
                    ? _fetchFirmwareInfo
                    : null,
                icon: _currentState == UpdateState.fetchingInfo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_download),
                label: const Text('Get Latest Version'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Güncellemeyi Başlat
        Card(
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Row(
                  children: [
                    Expanded(
                        child: Text(
                        'Start Update',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008E46),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed:
                        (_updateInfo != null &&
                            _updateInfo!.isUpdateAvailable &&
                            _currentState == UpdateState.ready)
                        ? _startUpdate
                        : null,
                    child: Text(_startUpdateSent ? 'Sent ✓' : 'Start'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
