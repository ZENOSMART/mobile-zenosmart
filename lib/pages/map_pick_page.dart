import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapPickResult {
  final double latitude;
  final double longitude;
  final String? address;
  const MapPickResult({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

class MapPickPage extends StatefulWidget {
  const MapPickPage({super.key, this.initialLat, this.initialLng});
  final double? initialLat;
  final double? initialLng;

  @override
  State<MapPickPage> createState() => _MapPickPageState();
}

class _MapPickPageState extends State<MapPickPage> {
  LatLng? _picked;
  String? _address;
  bool _resolving = false;
  final MapController _mapController = MapController();
  bool _loadingCenter = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _picked = LatLng(widget.initialLat!, widget.initialLng!);
    }
    // İlk açılışta kullanıcı konumuna odaklan
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final allowed = await _ensureLocationPermission();
      if (!mounted) return;
      try {
        if (allowed) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          final here = LatLng(pos.latitude, pos.longitude);
          setState(() {
            _picked = here;
            _loadingCenter = false;
          });
          await _reverseGeocode(here);
          try {
            _mapController.move(here, 16);
          } catch (_) {}
        } else {
          setState(() {
            _picked ??= const LatLng(39.92077, 32.85411);
            _loadingCenter = false;
          });
        }
      } catch (_) {
        setState(() {
          _picked ??= const LatLng(39.92077, 32.85411);
          _loadingCenter = false;
        });
      }
    });
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() {
      _resolving = true;
    });
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${point.latitude}&lon=${point.longitude}',
      );
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'zenosmart-app/1.0'},
      );
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        _address = json['display_name'] as String?;
      }
    } catch (_) {
      _address = null;
    } finally {
      if (mounted)
        setState(() {
          _resolving = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final center =
        _picked ??
        LatLng(widget.initialLat ?? 39.92077, widget.initialLng ?? 32.85411);
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/zenosmart-logo.png',
          height: 22,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
      ),
      body: _loadingCenter
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 13,
                    onTap: (tapPos, point) async {
                      setState(() {
                        _picked = point;
                      });
                      await _reverseGeocode(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.flutter_application_1',
                    ),
                    if (_picked != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _picked!,
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFF008E46),
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // Zoom controls
                Positioned(
                  right: 12,
                  bottom: 160,
                  child: Column(
                    children: [
                      _ZoomButton(
                        icon: Icons.add,
                        onPressed: () {
                          try {
                            final cam = _mapController.camera;
                            _mapController.move(cam.center, cam.zoom + 1);
                          } catch (_) {}
                        },
                      ),
                      const SizedBox(height: 8),
                      _ZoomButton(
                        icon: Icons.remove,
                        onPressed: () {
                          try {
                            final cam = _mapController.camera;
                            _mapController.move(cam.center, cam.zoom - 1);
                          } catch (_) {}
                        },
                      ),
                    ],
                  ),
                ),
                // My location button
                Positioned(
                  right: 12,
                  bottom: 100,
                  child: _ZoomButton(
                    icon: Icons.my_location,
                    onPressed: () async {
                      final allowed = await _ensureLocationPermission();
                      if (!allowed) return;
                      final pos = await Geolocator.getCurrentPosition(
                        desiredAccuracy: LocationAccuracy.high,
                      );
                      final here = LatLng(pos.latitude, pos.longitude);
                      setState(() {
                        _picked = here;
                      });
                      try {
                        _mapController.move(here, 16);
                      } catch (_) {}
                      await _reverseGeocode(here);
                    },
                  ),
                ),
                if (_resolving)
                  const Positioned(
                    left: 16,
                    right: 16,
                    bottom: 90,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_address != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 90,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _address!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008E46),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _picked == null
                  ? null
                  : () {
                      Navigator.of(context).pop<MapPickResult>(
                        MapPickResult(
                          latitude: _picked!.latitude,
                          longitude: _picked!.longitude,
                          address: _address,
                        ),
                      );
                    },
              child: const Text('Select Location'),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _ZoomButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: const Color(0xFF008e46),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Icon(icon, size: 20),
      ),
    );
  }
}

Future<bool> _ensureLocationPermission() async {
  LocationPermission perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  return perm == LocationPermission.always ||
      perm == LocationPermission.whileInUse;
}
