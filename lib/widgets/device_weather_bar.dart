import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeviceWeatherBar extends StatefulWidget {
  final String deviceRemoteId;
  final double? latitude; // Add this parameter
  final double? longitude; // Add this parameter

  const DeviceWeatherBar({
    super.key,
    required this.deviceRemoteId,
    this.latitude,
    this.longitude,
  });

  @override
  State<DeviceWeatherBar> createState() => _DeviceWeatherBarState();
}

class _DeviceWeatherBarState extends State<DeviceWeatherBar> {
  Map<String, dynamic>? _weatherData;
  String? _cityName;
  String? _district;
  bool _loading = true;
  bool _deviceDataAvailable = true; // Add this flag

  @override
  void initState() {
    super.initState();
    _loadDeviceLocationAndWeather();
  }

  @override
  void didUpdateWidget(DeviceWeatherBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Latitude veya longitude değiştiğinde yeniden yükle
    if (widget.latitude != oldWidget.latitude ||
        widget.longitude != oldWidget.longitude) {
      debugPrint(
        'DeviceWeatherBar: Latitude/Longitude changed. New: lat=${widget.latitude}, lng=${widget.longitude}',
      );
      _loadDeviceLocationAndWeather();
    }
  }

  Future<void> _loadDeviceLocationAndWeather() async {
    try {
      // Eğer latitude ve longitude verilmişse doğrudan kullan
      if (widget.latitude != null && widget.longitude != null) {
        setState(() {
          _loading = true;
          _deviceDataAvailable = true;
        });
        // 1. Şehir/ilçe bilgisini reverse geocoding ile al
        await _fetchCityInfo(widget.latitude!, widget.longitude!);

        // 2. Hava durumu bilgisini al
        await _fetchWeather(widget.latitude!, widget.longitude!);
        return;
      }

      // Eğer latitude ve longitude null ise cihazdan veri gelmemiş demektir
      setState(() {
        _loading = false;
        _deviceDataAvailable = false;
      });
    } catch (e) {
      debugPrint('Error loading location and weather: $e');
      setState(() {
        _loading = false;
        _deviceDataAvailable = false;
      });
    }
  }

  Future<void> _fetchCityInfo(double lat, double lng) async {
    try {
      // OpenStreetMap Nominatim reverse geocoding (ücretsiz)
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=tr',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'ZenosmartApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          setState(() {
            _cityName =
                address['city'] ??
                address['town'] ??
                address['province'] ??
                address['state'];
            _district =
                address['district'] ??
                address['suburb'] ??
                address['neighbourhood'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching city info: $e');
    }
  }

  Future<void> _fetchWeather(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,weather_code&timezone=auto',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _weatherData = data['current'];
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
      setState(() => _loading = false);
    }
  }

  IconData _getWeatherIcon(int? weatherCode) {
    // WMO Weather interpretation codes (detaylı)
    if (weatherCode == null) return Icons.cloud;

    switch (weatherCode) {
      case 0:
        return Icons.wb_sunny; // Clear sky
      case 1:
        return Icons.wb_sunny_outlined; // Mainly clear
      case 2:
        return Icons.cloud_outlined; // Partly cloudy
      case 3:
        return Icons.cloud; // Overcast
      case 45:
      case 48:
        return Icons.foggy; // Fog
      case 51:
      case 53:
      case 55:
        return Icons.grain; // Drizzle
      case 56:
      case 57:
        return Icons.ac_unit; // Freezing Drizzle
      case 61:
      case 63:
      case 65:
        return Icons.water_drop; // Rain
      case 66:
      case 67:
        return Icons.severe_cold; // Freezing Rain
      case 71:
      case 73:
      case 75:
        return Icons.ac_unit; // Snow fall
      case 77:
        return Icons.grain; // Snow grains
      case 80:
      case 81:
      case 82:
        return Icons.water_drop; // Rain showers
      case 85:
      case 86:
        return Icons.ac_unit; // Snow showers
      case 95:
        return Icons.thunderstorm; // Thunderstorm
      case 96:
      case 99:
        return Icons.flash_on; // Thunderstorm with hail
      default:
        return Icons.cloud;
    }
  }

  String _getWeatherDescription(int? weatherCode) {
    if (weatherCode == null) return '';

    switch (weatherCode) {
      case 0:
        return 'Clear Sky';
      case 1:
        return 'Mainly Clear';
      case 2:
        return 'Partly Cloudy';
      case 3:
        return 'Overcast';
      case 45:
        return 'Foggy';
      case 48:
        return 'Dense Fog';
      case 51:
        return 'Light Drizzle';
      case 53:
        return 'Moderate Drizzle';
      case 55:
        return 'Dense Drizzle';
      case 56:
        return 'Light Freezing Drizzle';
      case 57:
        return 'Dense Freezing Drizzle';
      case 61:
        return 'Light Rain';
      case 63:
        return 'Moderate Rain';
      case 65:
        return 'Heavy Rain';
      case 66:
        return 'Light Freezing Rain';
      case 67:
        return 'Heavy Freezing Rain';
      case 71:
        return 'Light Snow';
      case 73:
        return 'Moderate Snow';
      case 75:
        return 'Heavy Snow';
      case 77:
        return 'Snow Grains';
      case 80:
        return 'Light Rain Showers';
      case 81:
        return 'Moderate Rain Showers';
      case 82:
        return 'Violent Rain Showers';
      case 85:
        return 'Light Snow Showers';
      case 86:
        return 'Heavy Snow Showers';
      case 95:
        return 'Thunderstorm';
      case 96:
        return 'Thunderstorm with Light Hail';
      case 99:
        return 'Thunderstorm with Heavy Hail';
      default:
        return 'Unknown';
    }
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
            'Device Information Unavailable',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    if (_weatherData == null) {
      return const SizedBox.shrink();
    }

    final temp = _weatherData!['temperature_2m'];
    final weatherCode = _weatherData!['weather_code'] as int?;
    final tempCelsius = temp?.toStringAsFixed(0) ?? '--';
    final tempFahrenheit = temp != null
        ? ((temp * 9 / 5) + 32).toStringAsFixed(0)
        : '--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          // Hava durumu ikonu ve sıcaklık
          Icon(
            _getWeatherIcon(weatherCode),
            color: Colors.amber.shade700,
            size: 32,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '$tempCelsius°',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$tempFahrenheit°F',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
              Text(
                _getWeatherDescription(weatherCode),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
          const Spacer(),
          // Şehir ve ilçe bilgisi
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_cityName != null)
                Row(
                  children: [
                    Text(
                      _cityName!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.black87,
                    ),
                  ],
                ),
              if (_district != null)
                Text(
                  _district!,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
