import 'dart:typed_data';
import 'data_helper.dart';

class DeviceInfoDataHelper {
  static List<int> createDeviceInfoRequest() {
    const infoId = 1;
    const counter = 1;
    final data = [infoId];
    final header = DataHelper.prepareHeaderData('DI', data.length, counter);
    final packet = <int>[...header, ...data];
    final crc = DataHelper.calculateCRC(packet);
    packet.addAll(_intToBytes(crc));
    return packet;
  }

  static DeviceInfoResponse? parseDeviceInfoResponse(List<int> data) {
    if (data.length < 16) {
      return null;
    }

    try {
      final byteData = ByteData.sublistView(Uint8List.fromList(data));
      var index = 0;

      // OpCode kontrolü
      final opCodeValue = byteData.getUint16(index, Endian.little);
      final opCode = String.fromCharCodes([
        opCodeValue & 0xFF,
        (opCodeValue >> 8) & 0xFF,
      ]);

      if (opCode != 'DI') {
        return null;
      }

      index += 2; // OpCode
      final dataLength = byteData.getUint16(index, Endian.little);
      index += 2; // DataLength
      index += 2; // Counter (skip)

      if (dataLength != 7) {
        return null;
      }

      // Data parse et: infoId, hwMajor, hwMinor, hwPatch, swMajor, swMinor, swPatch
      final infoId = byteData.getUint8(index++);
      final hwMajor = byteData.getUint8(index++);
      final hwMinor = byteData.getUint8(index++);
      final hwPatch = byteData.getUint8(index++);
      final swMajor = byteData.getUint8(index++);
      final swMinor = byteData.getUint8(index++);
      final swPatch = byteData.getUint8(index++);

      return DeviceInfoResponse(
        infoId: infoId,
        hwVersionMajor: hwMajor,
        hwVersionMinor: hwMinor,
        hwVersionPatch: hwPatch,
        swVersionMajor: swMajor,
        swVersionMinor: swMinor,
        swVersionPatch: swPatch,
      );
    } catch (e) {
      return null;
    }
  }

  static List<int> createDeviceInfoData({
    required int hwVersionMajor,
    required int hwVersionMinor,
    required int hwVersionPatch,
    required int swVersionMajor,
    required int swVersionMinor,
    required int swVersionPatch,
  }) {
    // Sabit değerler
    const infoId = 1;
    const counter = 1;

    // Değerleri 0-255 aralığına sınırla
    final infoIdByte = infoId;
    final hwMajor = hwVersionMajor.clamp(0, 255);
    final hwMinor = hwVersionMinor.clamp(0, 255);
    final hwPatch = hwVersionPatch.clamp(0, 255);
    final swMajor = swVersionMajor.clamp(0, 255);
    final swMinor = swVersionMinor.clamp(0, 255);
    final swPatch = swVersionPatch.clamp(0, 255);

    // Data: infoId + 6 version byte = 7 byte
    final data = [
      infoIdByte,
      hwMajor,
      hwMinor,
      hwPatch,
      swMajor,
      swMinor,
      swPatch,
    ];

    // Header oluştur (OpCode: "DI", dataLength: 7, counter: 1)
    final header = DataHelper.prepareHeaderData('DI', data.length, counter);

    // Header + Data
    final packet = <int>[...header, ...data];

    // CRC hesapla ve ekle
    final crc = DataHelper.calculateCRC(packet);
    packet.addAll(_intToBytes(crc));

    return packet;
  }

  static List<int> _intToBytes(int value) {
    final byteData = ByteData(4);
    byteData.setUint32(0, value & 0xFFFFFFFF, Endian.little);
    return byteData.buffer.asUint8List();
  }
}

/// Cihazdan gelen DI response modeli
class DeviceInfoResponse {
  final int infoId;
  final int hwVersionMajor;
  final int hwVersionMinor;
  final int hwVersionPatch;
  final int swVersionMajor;
  final int swVersionMinor;
  final int swVersionPatch;

  DeviceInfoResponse({
    required this.infoId,
    required this.hwVersionMajor,
    required this.hwVersionMinor,
    required this.hwVersionPatch,
    required this.swVersionMajor,
    required this.swVersionMinor,
    required this.swVersionPatch,
  });
}
