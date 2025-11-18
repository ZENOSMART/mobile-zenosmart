import 'package:flutter/material.dart';
import '../helpers/channel_icon_helper.dart';
import '../helpers/sensor_data_helper.dart';

class SensorDataWidget extends StatelessWidget {
  final SensorDataResult sensorData;

  const SensorDataWidget({super.key, required this.sensorData});

  IconData _getIconByChannelCode(int? channelCode) {
    if (channelCode == null) return Icons.sensors;
    return ChannelIconHelper.getIcon(channelCode);
  }

  Color _getDimIconColor(double value) {
    final clampedValue = value.clamp(0.0, 100.0);
    final percentage = clampedValue / 100.0;

    if (percentage <= 0.5) {
      final localPercentage = percentage * 2; // 0-1 arası normalize et
      return Color.lerp(
        Colors.grey.shade700, // 0% - Koyu gri
        Colors.orange.shade600, // 50% - Turuncu
        localPercentage,
      )!;
    } else {
      // 50-100: Turuncu'dan sarıya geçiş
      final localPercentage = (percentage - 0.5) * 2; // 0-1 arası normalize et
      return Color.lerp(
        Colors.orange.shade600, // 50% - Turuncu
        Colors.yellow.shade600, // 100% - Sarı
        localPercentage,
      )!;
    }
  }

  Color _getIconColorByChannel(int? channelCode, double value) {
    if (channelCode == 1) {
      return _getDimIconColor(value);
    }
    return Colors.blue.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: Color(0xFF000000),
                ),
                const SizedBox(width: 4),
                Text(
                  '${sensorData.timestamp.day.toString().padLeft(2, '0')}.'
                  '${sensorData.timestamp.month.toString().padLeft(2, '0')}.'
                  '${sensorData.timestamp.year} '
                  '${sensorData.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${sensorData.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF000000),
                  ),
                ),
              ],
            ),
          ),
          // Kanal listesi
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: sensorData.channels.length,
            separatorBuilder: (context, index) =>
                Divider(color: Colors.grey.shade300, height: 1),
            itemBuilder: (context, index) {
              final channel = sensorData.channels[index];
              final iconColor = _getIconColorByChannel(
                channel.channelCode,
                channel.value,
              );

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getIconByChannelCode(channel.channelCode),
                        color: iconColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Kanal bilgisi
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            channel.enName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Değer
                    Text(
                      channel.value.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Footer: Counter ve CRC (opsiyonel)
          if (sensorData.counter > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Counter: ${sensorData.counter}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF000000),
                    ),
                  ),
                  Text(
                    'CRC: 0x${sensorData.crc.toRadixString(16).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF000000),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
