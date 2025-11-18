import 'dart:typed_data';
import 'device_settings_decoded_helper.dart';
import 'sensor_data_helper.dart';

enum OpCode { SD, LC, TC, TR, DS }

class OpCodeHandler {
  static Future<SensorDataResult?> handleData(
    String deviceId,
    List<int> dataByte,
  ) async {
    if (dataByte.length < 2) {
      print('Hata: Veri çok kısa (minimum 2 byte gerekli)');
      return null;
    }

    final byteData = ByteData.sublistView(Uint8List.fromList(dataByte));
    final opCodeValue = byteData.getUint16(0, Endian.little);
    final opCodeString = String.fromCharCodes([
      opCodeValue & 0xFF,
      (opCodeValue >> 8) & 0xFF,
    ]);

    print('OpCode String: $opCodeString');

    // OpCode'a göre ilgili fonksiyonu çağır
    final opCode = _getOpCodeFromString(opCodeString);
    if (opCode != null) {
      return await handleOpCode(opCode, deviceId, dataByte);
    } else {
      print('Bilinmeyen OpCode: $opCodeString');
      return null;
    }
  }

  static OpCode? _getOpCodeFromString(String opCodeStr) {
    switch (opCodeStr) {
      case 'SD':
        return OpCode.SD;
      case 'LC':
        return OpCode.LC;
      case 'TC':
        return OpCode.TC;
      case 'TR':
        return OpCode.TR;
      case 'DS':
        return OpCode.DS;
      default:
        return null;
    }
  }

  static Future<SensorDataResult?> handleOpCode(
    OpCode opCode,
    String deviceId,
    List<int> dataByte,
  ) async {
    switch (opCode) {
      case OpCode.SD:
        return await handleSD(deviceId, dataByte);
      case OpCode.LC:
        handleLC(deviceId, dataByte);
        return null;
      case OpCode.TC:
        handleTC(deviceId, dataByte);
        return null;
      case OpCode.TR:
        handleTR(deviceId, dataByte);
        return null;
      case OpCode.DS:
        handleDS(deviceId, dataByte);
        return null;
    }
  }

  static Future<SensorDataResult?> handleSD(
    String deviceId,
    List<int> dataByte,
  ) async {
    final result = await SensorDataHelper.parseSD(deviceId, dataByte);
    if (result != null) {
      print(result.toString());
      return result;
    } else {
      print('SD verisi parse edilemedi');
      return null;
    }
  }

  static void handleLC(String deviceId, List<int> dataByte) {
    print('LC işleniyor - Device ID: $deviceId');
    // LC işlemleri buraya gelecek
  }

  static void handleTC(String deviceId, List<int> dataByte) {
    print('TC işleniyor - Device ID: $deviceId');
    // TC işlemleri buraya gelecek
  }

  static void handleTR(String deviceId, List<int> dataByte) {
    print('TR işleniyor - Device ID: $deviceId');
    // TR işlemleri buraya gelecek
  }

  static void handleDS(String deviceId, List<int> dataByte) {
    final result = DeviceSettingsDecodedHelper.parse(deviceId, dataByte);
    if (result != null) {
      print(result.toString());
    } else {
      print('DS verisi parse edilemedi');
    }
  }
}
