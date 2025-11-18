import 'dart:typed_data';
import 'database_helper.dart';

class SensorDataHelper {
  static Future<SensorDataResult?> parseSD(
    String deviceId,
    List<int> dataByte,
  ) async {
    if (dataByte.length < 10) {
      print('Hata: SD için veri çok kısa');
      return null;
    }

    final byteData = ByteData.sublistView(Uint8List.fromList(dataByte));
    int index = 0;

    index += 2; // OpCode (2 byte)
    final dataLength = byteData.getUint16(index, Endian.little);
    index += 2; // DataLength (2 byte)
    final counter = byteData.getUint16(index, Endian.little);
    index += 2; // Counter (2 byte)

    if (index + dataLength + 4 > dataByte.length) {
      print('Hata: Veri uzunluğu yetersiz');
      return null;
    }

    // Zaman bilgisi (5 byte)
    final year = dataByte[index++];
    final month = dataByte[index++];
    final day = dataByte[index++];
    final hour = dataByte[index++];
    final minute = dataByte[index++];

    final timestamp = DateTime(2000 + year, month, day, hour, minute);

    // Cihaz kanallarını çek
    final channels = await DatabaseHelper.getDeviceChannels(deviceId);

    final channelValues = <ChannelValue>[];

    for (var channel in channels) {
      final channelCode = channel['channel_code'] as int?;
      final dataType = channel['data_type'] as String?;
      final byteLength = channel['data_byte_length'] as int?;
      final enName = channel['en_name'] as String?;
      final trName = channel['tr_name'] as String?;

      if (dataType == null || byteLength == null) continue;

      // Veri okuma
      final value = _readValue(byteData, index, dataType);
      index += byteLength; // Her durumda index'i artır

      if (value != null) {
        channelValues.add(
          ChannelValue(
            channelCode: channelCode,
            enName: enName ?? 'Unknown',
            trName: trName,
            value: value,
            dataType: dataType,
          ),
        );
      }
    }

    final crc = byteData.getUint32(dataByte.length - 4, Endian.little);

    return SensorDataResult(
      deviceId: deviceId,
      counter: counter,
      timestamp: timestamp,
      channels: channelValues,
      crc: crc,
    );
  }

  static double? _readValue(ByteData byteData, int index, String dataType) {
    try {
      switch (dataType.toLowerCase()) {
        case 'byte':
          return byteData.getInt8(index).toDouble();
        case 'ubyte':
          return byteData.getUint8(index).toDouble();
        case 'short':
          return byteData.getInt16(index, Endian.little).toDouble();
        case 'ushort':
          return byteData.getUint16(index, Endian.little).toDouble();
        case 'int':
          return byteData.getInt32(index, Endian.little).toDouble();
        case 'uint':
          return byteData.getUint32(index, Endian.little).toDouble();
        case 'float':
          return byteData.getFloat32(index, Endian.little);
        case 'ufloat':
          return byteData.getFloat32(index, Endian.little).abs();
        default:
          print('Bilinmeyen dataType: $dataType');
          return null;
      }
    } catch (e) {
      print('Veri okuma hatası: $e');
      return null;
    }
  }
}

class SensorDataResult {
  final String deviceId;
  final int counter;
  final DateTime timestamp;
  final List<ChannelValue> channels;
  final int crc;

  SensorDataResult({
    required this.deviceId,
    required this.counter,
    required this.timestamp,
    required this.channels,
    required this.crc,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('=== SD - Sensor Data ===');
    buffer.writeln('Device ID: $deviceId');
    buffer.writeln('Counter: $counter');
    buffer.writeln('Timestamp: ${timestamp.toString()}');
    buffer.writeln('Channels:');
    for (var channel in channels) {
      final codeStr = channel.channelCode != null
          ? '[${channel.channelCode}] '
          : '';
      buffer.writeln(
        '  $codeStr${channel.enName}: ${channel.value} (${channel.dataType})',
      );
    }
    buffer.writeln(
      'CRC: 0x${crc.toRadixString(16).toUpperCase().padLeft(8, '0')}',
    );
    buffer.writeln('=======================');
    return buffer.toString();
  }
}

class ChannelValue {
  final int? channelCode;
  final String enName;
  final String? trName;
  final double value;
  final String dataType;

  ChannelValue({
    this.channelCode,
    required this.enName,
    this.trName,
    required this.value,
    required this.dataType,
  });
}
