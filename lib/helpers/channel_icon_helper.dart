import 'package:flutter/material.dart';

class ChannelIconHelper {
  static const Map<int, IconData> _iconMap = {
    1: Icons.lightbulb_outline,
    2: Icons.water_drop,
    3: Icons.stop,
    4: Icons.water_drop,
    5: Icons.lightbulb,
    6: Icons.thermostat,
    7: Icons.battery_full,
    8: Icons.waves,
    9: Icons.electric_bolt,
    10: Icons.timer,
  };

  static IconData getIcon(int channelCode) {
    return _iconMap[channelCode] ?? Icons.tune;
  }
}
