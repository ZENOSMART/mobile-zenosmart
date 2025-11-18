class DataHelper {
  static List<int> prepareHeaderData(
    String opCode,
    int dataLength,
    int counter,
  ) {
    final t = opCode.trim();
    final int b0 = t.isNotEmpty ? (t.codeUnitAt(0) & 0xFF) : 0x00;
    final int b1 = t.length > 1 ? (t.codeUnitAt(1) & 0xFF) : 0x00;

    int toU16(int v) => v < 0 ? 0 : (v > 0xFFFF ? 0xFFFF : (v & 0xFFFF));
    final len = toU16(dataLength);
    final cnt = toU16(counter);

    return <int>[
      // opCode (2 ASCII bayt)
      b0,
      b1,
      // dataLength (LE)
      len & 0xFF,
      (len >> 8) & 0xFF,
      // counter (LE)
      cnt & 0xFF,
      (cnt >> 8) & 0xFF,
    ];
  }

  static int calculateCRC(List<int> bytes) {
    int sum = 0;
    for (int byte in bytes) {
      sum += byte & 0xFF;
    }
    return sum;
  }
}
