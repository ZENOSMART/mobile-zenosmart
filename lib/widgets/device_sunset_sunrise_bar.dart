import 'package:flutter/material.dart';
import 'dart:math';

class DeviceSunsetSunriseBar extends StatefulWidget {
  final String deviceRemoteId;
  final double? latitude;
  final double? longitude;

  const DeviceSunsetSunriseBar({
    super.key,
    required this.deviceRemoteId,
    this.latitude,
    this.longitude,
  });

  @override
  State<DeviceSunsetSunriseBar> createState() => _DeviceSunsetSunriseBarState();
}

class _DeviceSunsetSunriseBarState extends State<DeviceSunsetSunriseBar> {
  String? _sunriseTime;
  String? _sunsetTime;
  bool _loading = true;
  bool _deviceDataAvailable = true; // Add this flag

  @override
  void initState() {
    super.initState();
    _loadSunriseSunset();
  }

  @override
  void didUpdateWidget(DeviceSunsetSunriseBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Latitude veya longitude değiştiğinde yeniden yükle
    if (widget.latitude != oldWidget.latitude ||
        widget.longitude != oldWidget.longitude) {
      debugPrint(
        'DeviceSunsetSunriseBar: Latitude/Longitude değişti. Yeni: lat=${widget.latitude}, lng=${widget.longitude}',
      );
      _loadSunriseSunset();
    }
  }

  Future<void> _loadSunriseSunset() async {
    try {
      if (widget.latitude != null && widget.longitude != null) {
        setState(() {
          _loading = true;
          _deviceDataAvailable = true;
        });
        await _fetchSunriseSunset(widget.latitude!, widget.longitude!);
        return;
      }
      setState(() {
        _loading = false;
        _deviceDataAvailable = false;
      });
    } catch (e) {
      debugPrint('Gün doğumu/batımı yüklenirken hata: $e');
      setState(() {
        _loading = false;
        _deviceDataAvailable = false;
      });
    }
  }

  Future<void> _fetchSunriseSunset(double lat, double lng) async {
    try {
      final now = DateTime.now();
      final timezoneOffset = now.timeZoneOffset.inHours;

      // Gün doğumu ve batımını hesapla
      final times = _calculateSunriseSunset(
        lat,
        lng,
        timezoneOffset,
        now.year,
        now.month,
        now.day,
      );

      setState(() {
        _sunriseTime = _convertToHourMinute(times['sunrise']!);
        _sunsetTime = _convertToHourMinute(times['sunset']!);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Gün doğumu/batımı hesaplanırken hata: $e');
      setState(() => _loading = false);
    }
  }

  Map<String, double> _calculateSunriseSunset(
    double latitude,
    double longitude,
    int timezoneOffset,
    int year,
    int month,
    int day,
  ) {
    // 1. Gün sayısı (Day of year)
    int dayOfYear =
        (275 * month ~/ 9) -
        ((month + 9) ~/ 12) * (1 + ((year - 4 * (year ~/ 4) + 2) ~/ 3)) +
        day -
        30;

    // 2. Fractional year (radyan cinsinden)
    double gamma = (2 * pi / 365.0) * (dayOfYear - 1 + (12 - 12) / 24.0);

    // 3. Equation of time ve Solar declination
    double eqtime =
        229.18 *
        (0.000075 +
            0.001868 * cos(gamma) -
            0.032077 * sin(gamma) -
            0.014615 * cos(2 * gamma) -
            0.040849 * sin(2 * gamma));

    double decl =
        0.006918 -
        0.399912 * cos(gamma) +
        0.070257 * sin(gamma) -
        0.006758 * cos(2 * gamma) +
        0.000907 * sin(2 * gamma) -
        0.002697 * cos(3 * gamma) +
        0.00148 * sin(3 * gamma);

    // 4. Gün doğumu ve batımı için saat açısı (zenith = 90.833)
    double latRad = latitude * pi / 180.0;
    double ha = acos(
      cos(90.833 * pi / 180.0) / (cos(latRad) * cos(decl)) -
          tan(latRad) * tan(decl),
    );

    // 5. Gün doğumu ve batımı UTC dakikası
    double sunriseUtc = 720 - 4 * (longitude + ha * 180.0 / pi) - eqtime;
    double sunsetUtc = 720 - 4 * (longitude - ha * 180.0 / pi) - eqtime;

    // 6. Saat dilimi ofseti ile yerel saat
    double sunrise = ((sunriseUtc + timezoneOffset * 60) / 60.0) % 24.0;
    double sunset = ((sunsetUtc + timezoneOffset * 60) / 60.0) % 24.0;

    return {'sunrise': sunrise, 'sunset': sunset};
  }

  String _convertToHourMinute(double time) {
    int hour = time.floor();
    int minute = ((time - hour) * 60).floor();
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 60,
        color: Colors.white,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Eğer cihazdan veri gelmemişse "Cihaz Bilgileri Alınamıyor" mesajı göster
    if (!_deviceDataAvailable) {
      return Container(
        height: 60,
        color: Colors.white,
        child: const Center(
          child: Text(
            'Device data not available',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    if (_sunriseTime == null || _sunsetTime == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          // Gün doğumu
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wb_sunny, color: Colors.orange.shade700, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _sunriseTime!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const Text(
                      'Sunrise',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Ayırıcı çizgi
          Container(height: 40, width: 1, color: Colors.grey.shade400),
          // Gün batımı
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wb_twilight,
                  color: Colors.orange.shade700,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _sunsetTime!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const Text(
                      'Sunset',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
