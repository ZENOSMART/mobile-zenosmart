import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../repositories/device_channel_templates_repository.dart';
import 'data_helper.dart';

class LiveControlDataHelper {
  static final Random _random = Random();
  static int _uniqueCounter = 0;

  static Future<List<int>> handleLiveControlData({
    required String deviceId,
    required Map<String, dynamic> channelValues,
    int timeoutValue = 0,
  }) async {
    final totalChannels = channelValues.length;
    debugPrint(
      '[LiveControlDataHelper] Hazırlanıyor: $totalChannels kanal, timeout=$timeoutValue',
    );
    final channelRepo = const DeviceChannelTemplatesRepository();
    final writeChannels = await channelRepo.getWriteChannelsByDeviceId(
      deviceId,
    );

    if (writeChannels.isEmpty) {
      throw Exception('Bu cihaz için yazılabilir (W) kanal bulunamadı');
    }

    final dataBytes = <int>[];

    final timestamp = _generateUniqueLongValue();
    final timestampBytes = _longToBytes(timestamp);
    dataBytes.addAll(timestampBytes);
    debugPrint(
      '[LiveControlDataHelper] Timestamp=${timestamp.toRadixString(16)} bytes=$timestampBytes',
    );

    for (final channel in writeChannels) {
      final channelId = channel['id'] as String?;
      final channelCode = channel['channel_code'] as int?;
      final dataType = channel['data_type'] as String?;
      final dataByteLength = channel['data_byte_length'] as int? ?? 1;

      if (channelId == null || channelCode == null) continue;

      final value = channelValues[channelId];
      if (value == null) {
        dataBytes.addAll(List.filled(dataByteLength, 0));
        debugPrint(
          '[LiveControlDataHelper] Kanal $channelCode (id=$channelId) -> default 0x00',
        );
        continue;
      }

      final valueBytes = _encodeValueByDataType(
        value: value,
        dataType: dataType ?? 'byte',
        dataByteLength: dataByteLength,
      );
      dataBytes.addAll(valueBytes);
      debugPrint(
        '[LiveControlDataHelper] Kanal $channelCode (id=$channelId) -> $valueBytes (type=$dataType length=$dataByteLength value=$value)',
      );
    }

    final timeoutBytes = _shortToBytes(timeoutValue);
    dataBytes.addAll(timeoutBytes);

    final header = DataHelper.prepareHeaderData('LC', dataBytes.length, 1);

    final packet = <int>[];
    packet.addAll(header);
    packet.addAll(dataBytes);

    final crc = DataHelper.calculateCRC(packet);
    packet.add(crc & 0xFF);
    packet.add((crc >> 8) & 0xFF);
    packet.add((crc >> 16) & 0xFF);
    packet.add((crc >> 24) & 0xFF);

    debugPrint('[LiveControlDataHelper] Header=$header');
    debugPrint('[LiveControlDataHelper] DataBytes=$dataBytes');
    debugPrint(
      '[LiveControlDataHelper] CRC=0x${crc.toRadixString(16).padLeft(8, '0')}',
    );
    debugPrint('[LiveControlDataHelper] Packet=${packet.length} bytes $packet');

    return packet;
  }

  static List<int> _longToBytes(int value) {
    final buffer = ByteData(8);
    buffer.setUint64(0, value & 0xFFFFFFFFFFFFFFFF, Endian.little);
    return buffer.buffer.asUint8List();
  }

  static List<int> _shortToBytes(int value) {
    final clamped = value.clamp(0, 0xFFFF);
    return [clamped & 0xFF, (clamped >> 8) & 0xFF];
  }

  static List<int> _encodeValueByDataType({
    required dynamic value,
    required String dataType,
    required int dataByteLength,
  }) {
    switch (dataType.toLowerCase()) {
      case 'byte':
      case 'uint8':
        return [_toInt(value).clamp(0, 0xFF) & 0xFF];

      case 'short':
      case 'uint16':
      case 'int16':
        final intValue = _toInt(value).clamp(0, 0xFFFF);
        return [intValue & 0xFF, (intValue >> 8) & 0xFF];

      case 'int':
      case 'uint32':
      case 'int32':
        final intValue = _toInt(value);
        return [
          intValue & 0xFF,
          (intValue >> 8) & 0xFF,
          (intValue >> 16) & 0xFF,
          (intValue >> 24) & 0xFF,
        ];

      case 'long':
      case 'uint64':
      case 'int64':
        return _longToBytes(_toInt(value));

      case 'float':
        final buffer = ByteData(4);
        buffer.setFloat32(0, _toDouble(value), Endian.little);
        return buffer.buffer.asUint8List();

      case 'double':
        final buffer = ByteData(8);
        buffer.setFloat64(0, _toDouble(value), Endian.little);
        return buffer.buffer.asUint8List();

      case 'bool':
      case 'boolean':
        return [_toBool(value) ? 1 : 0];

      default:
        // Bilinmeyen tip için dataByteLength kadar 0 dön
        return List.filled(dataByteLength, 0);
    }
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is bool) return value ? 1 : 0;
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  static int _generateUniqueLongValue() {
    final timestamp = DateTime.now().microsecondsSinceEpoch & 0xFFFFFFFFFFFF;
    _uniqueCounter = (_uniqueCounter + 1) & 0xFFFF;
    final randomPart = _random.nextInt(1 << 16);
    final lower = (_uniqueCounter ^ randomPart) & 0xFFFF;
    return (timestamp << 16) | lower;
  }
}
