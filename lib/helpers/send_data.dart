import 'data_helper.dart';

class SendData {
  static List<int> sendGetSensor() {
    final header = DataHelper.prepareHeaderData("GS", 0, 1);
    final crc = DataHelper.calculateCRC(header);
    final data = [
      ...header,
      crc & 0xFF,
      (crc >> 8) & 0xFF,
      (crc >> 16) & 0xFF,
      (crc >> 24) & 0xFF,
    ];
    return data;
  }
}
