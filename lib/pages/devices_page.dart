import 'package:flutter/material.dart';
import '../repositories/device_repository.dart';
import 'device_detail_page.dart';
import 'device_type_page.dart';
import 'welcome_page.dart';
import 'about_help_page.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import '../repositories/device_detail_repository.dart';
import '../models/device_type.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final DeviceRepository _repo = const DeviceRepository();
  late Future<List<Map<String, Object?>>> _future;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  Widget _iconForTypeName(String? typeName) {
    final iconData = DeviceTypeExtension.iconFor(typeName);
    if (iconData != null) {
      return Icon(iconData, color: const Color(0xFF008E46));
    }
    if (typeName == null || typeName.trim().isEmpty || typeName == '-') {
      return const Icon(Icons.devices_other, color: Color(0xFF1E325A));
    }
    return const Icon(Icons.bluetooth, color: Color(0xFF1E325A));
  }

  @override
  void initState() {
    super.initState();
    _future = _repo.listAll();
  }

  Future<void> _refresh() async {
    setState(() {
      final q = _searchCtrl.text;
      _future = _repo.searchByName(q);
    });
    await _future;
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _future = _repo.searchByName(value);
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _connectAndNavigate({
    required String name,
    required String unique,
  }) async {
    final device = BluetoothDevice.fromId(unique);
    // Bağlanıyor dialogu
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // GIF animasyon (küçük)
              Image.asset(
                'assets/icons/zenopix-favikon.gif',
                width: 48,
                height: 48,
              ),
            ],
          ),
        ),
      ),
    );
    bool ok = false;
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      ok = true;
    } catch (_) {
      ok = false;
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    if (!mounted) return;
    if (ok) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeviceDetailPage(device: device, deviceName: name),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Connection could not be established. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomePage()),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F1F1),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const WelcomePage()),
              );
            },
          ),
          title: Image.asset(
            'assets/images/zenosmart-logo.png',
            height: 22,
            fit: BoxFit.contain,
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutHelpPage()),
                );
              },
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: const Icon(Icons.filter_list),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No registered device found. You can add one with the + button',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemBuilder: (context, index) {
                        final row = items[index];
                        final name = (row['name'] as String?) ?? '(unnamed)';
                        final deviceType =
                            (row['device_type'] as String?) ?? '-';
                        final deviceTypeName =
                            (row['device_type_name'] as String?) ??
                            DeviceTypeExtension.formatDisplayName(deviceType);
                        final unique = row['unique_data'] as String?;
                        final id = row['id'] as String; // PK (UUID)
                        return Dismissible(
                          key: Key('device_$id'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: const Color(0xFFDD0303),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Delete?'),
                                      content: Text(
                                        'Are you sure you want to delete the device "$name"?',
                                      ),
                                      actions: [
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFF1E325A,
                                            ),
                                          ),
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFF1E325A,
                                            ),
                                          ),
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text('Yes, Delete'),
                                        ),
                                      ],
                                    );
                                  },
                                ) ??
                                false;
                          },
                          onDismissed: (direction) async {
                            // Önce detay tablosundan sil, sonra ana cihazı sil
                            await const DeviceDetailRepository()
                                .deleteByDeviceId(id);
                            await _repo.deleteById(id);
                            if (mounted) await _refresh();
                          },
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
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              leading: SizedBox(
                                width: 40,
                                child: Center(
                                  child: _iconForTypeName(deviceType),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                'Type: $deviceTypeName\nKey: ${unique ?? ''}',
                              ),
                              isThreeLine: true,
                              onTap: (unique == null || unique.isEmpty)
                                  ? null
                                  : () async {
                                      await _connectAndNavigate(
                                        name: name,
                                        unique: unique,
                                      );
                                    },
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008E46),
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                      elevation: 2,
                    ),
                    onPressed: () async {
                      final added = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const DeviceTypePage(),
                        ),
                      );
                      if (added == true && mounted) {
                        await _refresh();
                      }
                    },
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
