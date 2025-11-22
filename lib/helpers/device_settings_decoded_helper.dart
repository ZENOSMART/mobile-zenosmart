import 'dart:typed_data';

class DeviceSettingsDecodedHelper {
  const DeviceSettingsDecodedHelper._();

  static DeviceSettingsDecodedResult? parse(
    String deviceId,
    List<int> dataByte,
  ) {
    if (dataByte.length < 11) {
      print('Hata: DS için veri çok kısa');
      return null;
    }

    final byteData = ByteData.sublistView(Uint8List.fromList(dataByte));
    var index = 0;

    final opCodeValue = byteData.getUint16(index, Endian.little);
    final opCode = String.fromCharCodes([
      opCodeValue & 0xFF,
      (opCodeValue >> 8) & 0xFF,
    ]);

    if (opCode != 'DS') {
      print('Hata: Beklenen OpCode DS, gelen $opCode');
      return null;
    }

    index += 2; // OpCode
    final dataLength = byteData.getUint16(index, Endian.little);
    index += 2; // DataLength
    final counter = byteData.getUint16(index, Endian.little);
    index += 2; // Counter

    final expectedPayloadEnd = index + dataLength;
    if (expectedPayloadEnd + 4 > dataByte.length) {
      print('Hata: Veri uzunluğu yetersiz');
      return null;
    }

    final groupId = byteData.getUint8(index);
    index += 1;

    final payloadBytes = dataByte.sublist(index, expectedPayloadEnd);
    final crc = byteData.getUint32(dataByte.length - 4, Endian.little);

    switch (groupId) {
      case 3:
        return _parseIdentityPayload(
          deviceId: deviceId,
          counter: counter,
          crc: crc,
          payloadBytes: payloadBytes,
        );
      case 4:
        return _parseGeneralSettingsPayload(
          deviceId: deviceId,
          counter: counter,
          crc: crc,
          payloadBytes: payloadBytes,
        );
      case 5:
        return _parseConfigSettingsPayload(
          deviceId: deviceId,
          counter: counter,
          crc: crc,
          payloadBytes: payloadBytes,
        );
      default:
        return DeviceSettingsDecodedResult(
          deviceId: deviceId,
          counter: counter,
          groupId: groupId,
          crc: crc,
          rawPayload: payloadBytes,
        );
    }
  }

  static DeviceSettingsDecodedResult? _parseIdentityPayload({
    required String deviceId,
    required int counter,
    required int crc,
    required List<int> payloadBytes,
  }) {
    if (payloadBytes.length < 20) {
      print('Hata: Kimlik bilgisi için veri çok kısa');
      return null;
    }

    final devEuiBytes = payloadBytes.sublist(0, 8);
    final joinEuiBytes = payloadBytes.sublist(8, 16);

    // deviceAddr'i little endian olarak oku
    final byteData = ByteData.sublistView(Uint8List.fromList(payloadBytes));
    final deviceAddrValue = byteData.getUint32(16, Endian.little);
    // Hex formatında göstermek için big endian byte sırasına çevir
    final deviceAddrBytes = [
      (deviceAddrValue >> 24) & 0xFF,
      (deviceAddrValue >> 16) & 0xFF,
      (deviceAddrValue >> 8) & 0xFF,
      deviceAddrValue & 0xFF,
    ];

    final identity = DeviceSettingsIdentity(
      devEui: _bytesToHex(devEuiBytes),
      joinEui: _bytesToHex(joinEuiBytes),
      deviceAddr: _bytesToHex(deviceAddrBytes),
    );

    return DeviceSettingsDecodedResult(
      deviceId: deviceId,
      counter: counter,
      groupId: 3,
      crc: crc,
      identity: identity,
    );
  }

  static DeviceSettingsDecodedResult? _parseGeneralSettingsPayload({
    required String deviceId,
    required int counter,
    required int crc,
    required List<int> payloadBytes,
  }) {
    if (payloadBytes.length < 12) {
      print('Hata: Genel ayarlar için veri çok kısa');
      return null;
    }

    final byteData = ByteData.sublistView(Uint8List.fromList(payloadBytes));
    var index = 0;

    int readUint16() {
      final value = byteData.getUint16(index, Endian.little);
      index += 2;
      return value;
    }

    int readUint8() {
      final value = byteData.getUint8(index);
      index += 1;
      return value;
    }

    final general = DeviceSettingsGeneral(
      bleUartWakeupSeconds: readUint16(),
      minPackTimeSeconds: readUint16(),
      uplinkInterval: readUint16(),
      isConfirmed: readUint8() == 1,
      isConfirmedResendManual: readUint8(),
      frequency: readUint8(),
      platform: readUint8(),
      activationType: payloadBytes.length > index ? readUint8() : null,
      dataRate: payloadBytes.length > index ? readUint8() : null,
    );

    return DeviceSettingsDecodedResult(
      deviceId: deviceId,
      counter: counter,
      groupId: 4,
      crc: crc,
      general: general,
    );
  }

  static DeviceSettingsDecodedResult? _parseConfigSettingsPayload({
    required String deviceId,
    required int counter,
    required int crc,
    required List<int> payloadBytes,
  }) {
    // Beklenen: latitude (4) + longitude (4) + timezone (1) + dayOfWeek (1) + year (1) + month (1) + day (1) + hour (1) + minute (1) + second (1) = 16 bytes
    if (payloadBytes.length < 16) {
      print(
        'Hata: Config ayarları için veri çok kısa. Beklenen: 16, Gelen: ${payloadBytes.length}',
      );
      return null;
    }

    final byteData = ByteData.sublistView(Uint8List.fromList(payloadBytes));
    var index = 0;

    double readFloat() {
      final value = byteData.getFloat32(index, Endian.little);
      index += 4;
      return value;
    }

    int readUint8() {
      final value = byteData.getUint8(index);
      index += 1;
      return value;
    }

    // Signed byte okuma fonksiyonu (timezone için)
    int readInt8() {
      final value = byteData.getUint8(index);
      index += 1;
      // Signed byte: 0-127 pozitif, 128-255 negatif (-128 ile -1 arası)
      return value > 127 ? value - 256 : value;
    }

    final config = DeviceConfigSettings(
      latitude: readFloat(), // 4 bytes
      longitude: readFloat(), // 4 bytes
      timezone: readInt8(), // 1 byte (signed: -12 to 14)
      dayOfWeek: readUint8(), // 1 byte
      year: readUint8() + 2000, // 1 byte (year - 2000)
      month: readUint8(), // 1 byte
      day: readUint8(), // 1 byte
      hour: readUint8(), // 1 byte
      minute: readUint8(), // 1 byte
      second: readUint8(), // 1 byte
    );

    return DeviceSettingsDecodedResult(
      deviceId: deviceId,
      counter: counter,
      groupId: 5,
      crc: crc,
      config: config,
    );
  }
}

class DeviceSettingsDecodedResult {
  final String deviceId;
  final int counter;
  final int groupId;
  final int crc;
  final DeviceSettingsIdentity? identity;
  final DeviceSettingsGeneral? general;
  final DeviceConfigSettings? config;
  final List<int>? rawPayload;

  DeviceSettingsDecodedResult({
    required this.deviceId,
    required this.counter,
    required this.groupId,
    required this.crc,
    this.identity,
    this.general,
    this.config,
    this.rawPayload,
  });

  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln('=== DS - Device Settings ===')
      ..writeln('Device ID: $deviceId')
      ..writeln('Counter: $counter')
      ..writeln('Group ID: $groupId')
      ..writeln(
        'CRC: 0x${crc.toRadixString(16).toUpperCase().padLeft(8, '0')}',
      );

    if (identity != null) {
      buffer
        ..writeln('--- Identity ---')
        ..writeln('devEui: ${identity!.devEui}')
        ..writeln('joinEui: ${identity!.joinEui}')
        ..writeln('deviceAddr: ${identity!.deviceAddr}');
    } else if (general != null) {
      buffer
        ..writeln('--- General Settings ---')
        ..writeln('minPackTimeSeconds: ${general!.minPackTimeSeconds}')
        ..writeln('bleUartWakeupSeconds: ${general!.bleUartWakeupSeconds}')
        ..writeln('uplinkInterval: ${general!.uplinkInterval}')
        ..writeln('isConfirmed: ${general!.isConfirmed}')
        ..writeln(
          'isConfirmedResendManual: ${general!.isConfirmedResendManual}',
        )
        ..writeln('frequency: ${general!.frequency}')
        ..writeln('platform: ${general!.platform}')
        ..writeln('activationType: ${general!.activationType}')
        ..writeln('dataRate: ${general!.dataRate}');
    } else if (config != null) {
      buffer
        ..writeln('--- Config Settings ---')
        ..writeln('latitude: ${config!.latitude}')
        ..writeln('longitude: ${config!.longitude}')
        ..writeln('timezone: ${config!.timezone}')
        ..writeln('dayOfWeek: ${config!.dayOfWeek}')
        ..writeln('year: ${config!.year}')
        ..writeln('month: ${config!.month}')
        ..writeln('day: ${config!.day}')
        ..writeln('hour: ${config!.hour}')
        ..writeln('minute: ${config!.minute}')
        ..writeln('second: ${config!.second}');
    } else if (rawPayload != null) {
      buffer
        ..writeln('--- Raw Payload ---')
        ..writeln(_bytesToHex(rawPayload!));
    }

    buffer.writeln('==========================');
    return buffer.toString();
  }
}

class DeviceSettingsIdentity {
  final String devEui;
  final String joinEui;
  final String deviceAddr;

  DeviceSettingsIdentity({
    required this.devEui,
    required this.joinEui,
    required this.deviceAddr,
  });
}

String _bytesToHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString().toUpperCase();
}

class DeviceSettingsGeneral {
  final int minPackTimeSeconds;
  final int bleUartWakeupSeconds;
  final int uplinkInterval;
  final bool isConfirmed;
  final int isConfirmedResendManual;
  final int frequency;
  final int platform;
  final int? activationType;
  final int? dataRate;

  DeviceSettingsGeneral({
    required this.minPackTimeSeconds,
    required this.bleUartWakeupSeconds,
    required this.uplinkInterval,
    required this.isConfirmed,
    required this.isConfirmedResendManual,
    required this.frequency,
    required this.platform,
    this.activationType,
    this.dataRate,
  });
}

class DeviceConfigSettings {
  final double latitude;
  final double longitude;
  final int timezone;
  final int dayOfWeek;
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final int second;

  DeviceConfigSettings({
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.dayOfWeek,
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.second,
  });

  @override
  String toString() {
    return 'DeviceConfigSettings{latitude: $latitude, longitude: $longitude, timezone: $timezone, dayOfWeek: $dayOfWeek, year: $year, month: $month, day: $day, hour: $hour, minute: $minute, second: $second}';
  }
}
