import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'data_helper.dart';

class TaskRequestHelper {
  static List<List<int>> createGetTaskData() {
    const counter = 1;
    final packets = <List<int>>[];

    for (int index = 0; index < 20; index++) {
      final data = [index];
      final header = DataHelper.prepareHeaderData('GT', data.length, counter);
      final packet = <int>[...header, ...data];
      final crc = DataHelper.calculateCRC(packet);
      packet.addAll(_intToBytes(crc));
      packets.add(packet);
    }

    return packets;
  }

  static GetTask? getTaskResponseDecoded(List<int> data) {
    if (data.length < 44) {
      return null;
    }

    try {
      final byteData = ByteData.sublistView(Uint8List.fromList(data));
      int index = 0;

      // OpCode kontrolü (2 byte)
      final opCodeValue = byteData.getUint16(index, Endian.little);
      final opCode = String.fromCharCodes([
        opCodeValue & 0xFF,
        (opCodeValue >> 8) & 0xFF,
      ]);

      if (opCode != 'GR') {
        return null;
      }

      index += 2; // OpCode
      index += 2; // DataLength (skip)
      index += 2; // Counter (skip)

      final taskIndex = byteData.getUint8(index++);
      final taskProfileId = byteData.getUint32(index, Endian.little);
      index += 4;
      final isIndividual = byteData.getUint8(index++);
      final status = byteData.getUint8(index++);
      final startYear = byteData.getUint8(index++);
      final startMonth = byteData.getUint8(index++);
      final startDay = byteData.getUint8(index++);
      final endYear = byteData.getUint8(index++);
      final endMonth = byteData.getUint8(index++);
      final endDay = byteData.getUint8(index++);
      final priority = byteData.getUint8(index++);
      final cyclicType = byteData.getUint8(index++);
      final cyclicTime = byteData.getUint8(index++);
      final offDaysMask = byteData.getUint8(index++);
      final channelNumber = byteData.getUint8(index++);

      // 4 kez onTime, offTime, value
      final timeSlots = <TimeSlot>[];
      for (int i = 0; i < 4; i++) {
        final onTimeHour = byteData.getUint8(index++);
        final onTimeMinute = byteData.getUint8(index++);
        final offTimeHour = byteData.getUint8(index++);
        final offTimeMinute = byteData.getUint8(index++);
        final value = byteData.getUint8(index++);

        timeSlots.add(
          TimeSlot(
            onTime:
                '${onTimeHour.toString().padLeft(2, '0')}:${onTimeMinute.toString().padLeft(2, '0')}',
            offTime:
                '${offTimeHour.toString().padLeft(2, '0')}:${offTimeMinute.toString().padLeft(2, '0')}',
            value: value,
          ),
        );
      }

      // Tarihleri string formatına çevir
      final startDate =
          '${(2000 + startYear).toString().padLeft(4, '0')}-${startMonth.toString().padLeft(2, '0')}-${startDay.toString().padLeft(2, '0')}';
      final endDate =
          '${(2000 + endYear).toString().padLeft(4, '0')}-${endMonth.toString().padLeft(2, '0')}-${endDay.toString().padLeft(2, '0')}';

      return GetTask(
        index: taskIndex,
        taskProfileId: taskProfileId,
        isIndividual: isIndividual == 1,
        status: status,
        startDate: startDate,
        endDate: endDate,
        priority: priority,
        cyclicType: cyclicType,
        cyclicTime: cyclicTime,
        offDaysMask: offDaysMask,
        channelNumber: channelNumber,
        timeSlots: timeSlots,
      );
    } catch (e) {
      return null;
    }
  }

  static List<int> taskControlRequestData({
    required int taskProfileId,
    required int channelNumber,
    required int slotNumber,
    int counter = 1,
  }) {
    debugPrint(
      'taskControlRequestData: $taskProfileId, $channelNumber, $slotNumber',
    );

    final data = <int>[];
    // 4 byte int taskProfileId (little endian)
    final profileIdBytes = ByteData(4);
    profileIdBytes.setUint32(0, taskProfileId & 0xFFFFFFFF, Endian.little);
    data.addAll(profileIdBytes.buffer.asUint8List());

    // 1 byte channelNumber
    data.add(channelNumber & 0xFF);

    // 1 byte slotNumber (1-4)
    data.add(slotNumber & 0xFF);

    final header = DataHelper.prepareHeaderData('TY', data.length, counter);
    final packet = <int>[...header, ...data];
    final crc = DataHelper.calculateCRC(packet);
    packet.addAll(_intToBytes(crc));

    return packet;
  }

  static TaskControlLog? taskControlLogsDecoded(List<int> data) {
    if (data.length < 18) {
      // Minimum: 6 byte header + 12 byte data = 18 byte
      return null;
    }

    try {
      final byteData = ByteData.sublistView(Uint8List.fromList(data));
      int index = 0;

      // OpCode kontrolü (2 byte)
      final opCodeValue = byteData.getUint16(index, Endian.little);
      final opCode = String.fromCharCodes([
        opCodeValue & 0xFF,
        (opCodeValue >> 8) & 0xFF,
      ]);

      if (opCode != 'TC') {
        return null;
      }

      index += 2; // OpCode
      index += 2; // DataLength (skip)
      index += 2; // Counter (skip)

      // Data parse et
      final taskProfileId = byteData.getUint32(index, Endian.little);
      index += 4;
      final channelNumber = byteData.getUint8(index++);
      final controlYear = byteData.getUint8(index++);
      final controlMonth = byteData.getUint8(index++);
      final controlDay = byteData.getUint8(index++);
      final controlHour = byteData.getUint8(index++);
      final controlMin = byteData.getUint8(index++);
      final value = byteData.getUint8(index++);
      final controlType = byteData.getUint8(index++);

      // Tarih ve zamanı string formatına çevir
      final controlDate =
          '${(2000 + controlYear).toString().padLeft(4, '0')}-${controlMonth.toString().padLeft(2, '0')}-${controlDay.toString().padLeft(2, '0')}';
      final controlTime =
          '${controlHour.toString().padLeft(2, '0')}:${controlMin.toString().padLeft(2, '0')}';

      return TaskControlLog(
        taskProfileId: taskProfileId,
        channelNumber: channelNumber,
        controlDate: controlDate,
        controlTime: controlTime,
        value: value,
        controlType: controlType,
      );
    } catch (e) {
      return null;
    }
  }

  static List<int> _intToBytes(int value) {
    final byteData = ByteData(4);
    byteData.setUint32(0, value & 0xFFFFFFFF, Endian.little);
    return byteData.buffer.asUint8List();
  }
}

/// Task zaman slotu
class TimeSlot {
  final String onTime;
  final String offTime;
  final int value;

  TimeSlot({required this.onTime, required this.offTime, required this.value});
}

/// Cihazdan gelen GR (Get Task) response modeli
class GetTask {
  final int index;
  final int taskProfileId;
  final bool isIndividual;
  final int status;
  final String startDate;
  final String endDate;
  final int priority;
  final int cyclicType;
  final int cyclicTime;
  final int offDaysMask;
  final int channelNumber;
  final List<TimeSlot> timeSlots;

  GetTask({
    required this.index,
    required this.taskProfileId,
    required this.isIndividual,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.priority,
    required this.cyclicType,
    required this.cyclicTime,
    required this.offDaysMask,
    required this.channelNumber,
    required this.timeSlots,
  });
}

/// Cihazdan gelen TC (Task Control Logs) response modeli
class TaskControlLog {
  final int taskProfileId;
  final int channelNumber;
  final String controlDate;
  final String controlTime;
  final int value;
  final int controlType;

  TaskControlLog({
    required this.taskProfileId,
    required this.channelNumber,
    required this.controlDate,
    required this.controlTime,
    required this.value,
    required this.controlType,
  });
}
