import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'data_helper.dart';

class DeviceSettingsHelper {
  const DeviceSettingsHelper._();

  static List<int> createDeviceCredentials({
    required String devEui,
    required String joinEui,
    int counter = 1,
    int groupId = 3,
    List<int>? deviceAddr,
  }) {
    final devEuiBytes = _hexToBytes(devEui, 8);
    final joinEuiBytes = _hexToBytes(joinEui, 8);
    final addr = deviceAddr ?? List<int>.filled(4, 0);
    if (addr.length != 4) {
      throw ArgumentError.value(
        deviceAddr,
        'deviceAddr',
        '4 bayt uzunluğunda olmalı',
      );
    }

    final payload = <int>[
      groupId & 0xFF,
      ...devEuiBytes,
      ...joinEuiBytes,
      ...addr.map((value) => value & 0xFF),
    ];

    final header = DataHelper.prepareHeaderData('DS', payload.length, counter);

    final packet = <int>[...header, ...payload];

    final crc = DataHelper.calculateCRC(packet);
    packet.addAll(_intToBytes(crc));

    return packet;
  }

  static List<int> createDeviceGeneralSettings({
    required int bleUartWakeupSeconds,
    required int minPackTimeSeconds,
    required int uplinkInterval,
    bool isConfirmed = true,
    int isConfirmedResendManual = 1,
    int activationType = 0,
    int dataRate = 0,
    int counter = 1,
    int groupId = 4,
  }) {
    final payload = <int>[
      groupId & 0xFF, // 1 byte
      ..._uint16ToBytes(bleUartWakeupSeconds), // 2 bytes
      ..._uint16ToBytes(minPackTimeSeconds), // 2 bytes
      ..._uint16ToBytes(uplinkInterval), // 2 bytes
      isConfirmed ? 1 : 0, // 1 byte
      isConfirmedResendManual & 0xFF, // 1 byte
      0x00, // 1 byte: frequency sabit 0
      0x00, // 1 byte: platform sabit 0
      activationType & 0xFF, // 1 byte
      dataRate & 0xFF, // 1 byte
    ];

    final header = DataHelper.prepareHeaderData('DS', payload.length, counter);
    final packet = <int>[...header, ...payload];

    final crc = DataHelper.calculateCRC(packet);
    packet.addAll(_intToBytes(crc));

    return packet;
  }

  static List<int> createDeviceSettingsRequest({
    required int requestGroupId,
    int counter = 1,
  }) {
    const groupId = 0xFF;
    final payload = <int>[groupId & 0xFF, requestGroupId & 0xFF];
    final header = DataHelper.prepareHeaderData('DS', payload.length, counter);
    final packet = <int>[...header, ...payload];
    final crc = DataHelper.calculateCRC(packet);
    packet.addAll(_intToBytes(crc));
    return packet;
  }

  static List<int> createDeviceConfigSettings({
    required double latitude,
    required double longitude,
    int counter = 1,
    int groupId = 5,
  }) {
    debugPrint(
      'createDeviceConfigSettings Latitude: $latitude, Longitude: $longitude',
    );

    final now = DateTime.now();
    final timezoneOffsetHours = now.timeZoneOffset.inHours.clamp(-12, 14);
    final configYear = (now.year - 2000).clamp(0, 255);
    final configMonth = now.month;
    final configDay = now.day;
    final configDayOfWeek = now.weekday % 7;
    final configHour = now.hour;
    final configMinute = now.minute;
    final configSecond = now.second;

    final timezoneByte = timezoneOffsetHours < 0
        ? (256 + timezoneOffsetHours) & 0xFF
        : timezoneOffsetHours & 0xFF;

    // Latitude ve longitude byte'larını al
    final latitudeBytes = _floatToBytes(latitude);
    final longitudeBytes = _floatToBytes(longitude);

    final payload = <int>[
      groupId & 0xFF, // 1 byte: groupId
      ...latitudeBytes, // 4 bytes: latitude (float)
      ...longitudeBytes, // 4 bytes: longitude (float)
      timezoneByte, // 1 byte: timezone (signed byte: -12 to 14)
      configDayOfWeek & 0xFF, // 1 byte: dayOfWeek (mod 7, 0-6)
      configYear & 0xFF, // 1 byte: year (year - 2000, 0-255)
      configMonth & 0xFF, // 1 byte: month (1-12)
      configDay & 0xFF, // 1 byte: day (1-31)
      configHour & 0xFF, // 1 byte: hour (0-23)
      configMinute & 0xFF, // 1 byte: minute (0-59)
      configSecond & 0xFF, // 1 byte: second (0-59)
    ];

    debugPrint('📦 Payload length: ${payload.length} bytes');
    debugPrint(
      '📦 Payload (hex): ${payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}',
    );
    debugPrint('📦 Payload (dec): $payload');
    debugPrint('═══════════════════════════════════════════════════════');

    final header = DataHelper.prepareHeaderData('DS', payload.length, counter);
    final packet = <int>[...header, ...payload];
    final crc = DataHelper.calculateCRC(packet);
    packet.addAll(_intToBytes(crc));

    return packet;
  }

  static List<int> createDeviceReset({int counter = 1}) {
    final header = DataHelper.prepareHeaderData('DR', 0, counter);
    final packet = <int>[...header];
    final crc = DataHelper.calculateCRC(packet);
    packet.addAll(_intToBytes(crc));
    return packet;
  }

  static List<int> createDeviceClear({int counter = 1}) {
    final header = DataHelper.prepareHeaderData('CA', 0, counter);
    final packet = <int>[...header];
    final crc = DataHelper.calculateCRC(packet);
    packet.addAll(_intToBytes(crc));
    return packet;
  }

  static List<int> _hexToBytes(String input, int expectedLength) {
    final hex = input.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    if (hex.length != expectedLength * 2) {
      throw FormatException(
        'Beklenen uzunluk: ${expectedLength * 2} hex karakter, gelen: ${hex.length}',
      );
    }
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  static List<int> _intToBytes(int value) {
    final byteData = ByteData(4);
    byteData.setUint32(0, value & 0xFFFFFFFF, Endian.little);
    return byteData.buffer.asUint8List();
  }

  static List<int> _uint16ToBytes(int value) {
    final byteData = ByteData(2);
    byteData.setUint16(0, value & 0xFFFF, Endian.little);
    return byteData.buffer.asUint8List();
  }

  static List<int> _floatToBytes(double value) {
    final byteData = ByteData(4);
    byteData.setFloat32(0, value, Endian.little);
    return byteData.buffer.asUint8List();
  }
}
