import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../helpers/task_request_helper.dart';

class ProgramPage extends StatefulWidget {
  const ProgramPage({
    super.key,
    required this.rxCharacteristic,
    required this.txCharacteristic,
    required this.writeWithoutResponse,
    this.deviceName,
  });

  final BluetoothCharacteristic rxCharacteristic;
  final BluetoothCharacteristic? txCharacteristic;
  final bool writeWithoutResponse;
  final String? deviceName;

  @override
  State<ProgramPage> createState() => _ProgramPageState();
}

class _ProgramPageState extends State<ProgramPage> {
  bool _sending = false;
  int _currentIndex = 0;
  String? _errorMessage;
  String? _successMessage;
  StreamSubscription<List<int>>? _txCharSub;
  final Map<int, GetTask?> _tasks = {};
  final Map<String, List<TaskControlLog>> _taskLogs = {};
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _txCharSub?.cancel();
    super.dispose();
  }

  void _startListening() {
    if (widget.txCharacteristic == null || _listening) return;

    _listening = true;
    _txCharSub = widget.txCharacteristic!.lastValueStream.listen((data) {
      if (data.isNotEmpty && data.length >= 2) {
        final opCode = String.fromCharCodes([data[0], data[1]]);
        if (opCode == 'GR') {
          final task = TaskRequestHelper.getTaskResponseDecoded(data);
          if (task != null) {
            setState(() {
              _tasks[task.index] = task;
            });
          }
        } else if (opCode == 'TC') {
          // Handle concatenated packets or single packet
          int offset = 0;
          while (offset < data.length) {
            // Minimum header size kontrolü - sessizce çık
            if (data.length - offset < 6) {
              break;
            }
            
            // Read dataLength from header
            final byteData = ByteData.sublistView(Uint8List.fromList(data));
            final dataLength = byteData.getUint16(offset + 2, Endian.little);
            final packetSize = 6 + dataLength + 4; // header + data + CRC
            
            if (offset + packetSize > data.length) {
              // Incomplete packet, wait for more data - sessizce çık
              break;
            }
            
            // Extract single packet
            final packet = data.sublist(offset, offset + packetSize);
            final log = TaskRequestHelper.taskControlLogsDecoded(packet);
            
            if (log != null) {
              final key = '${log.taskProfileId}_${log.channelNumber}';
              final existingLogs = _taskLogs[key] ?? [];
              
              // Aynı log'un zaten eklenip eklenmediğini kontrol et
              final isDuplicate = existingLogs.any((existingLog) =>
                  existingLog.taskProfileId == log.taskProfileId &&
                  existingLog.channelNumber == log.channelNumber &&
                  existingLog.controlDate == log.controlDate &&
                  existingLog.controlTime == log.controlTime &&
                  existingLog.value == log.value &&
                  existingLog.controlType == log.controlType);
              
              if (!isDuplicate) {
                debugPrint('========================================');
                debugPrint('Task Control Log Received:');
                debugPrint('Task Profile ID: ${log.taskProfileId}');
                debugPrint('Channel Number: ${log.channelNumber}');
                debugPrint('Control Date: ${log.controlDate}');
                debugPrint('Control Time: ${log.controlTime}');
                debugPrint('Value: ${log.value}');
                debugPrint('Control Type: ${log.controlType}');
                debugPrint('========================================');
                setState(() {
                  _taskLogs.putIfAbsent(key, () => []).add(log);
                });
              }
            }
            
            offset += packetSize;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName ?? 'Program'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          if (_successMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _sendAllTaskData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008E46),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, size: 20),
                label: Text(_sending ? 'Sending...' : 'Send Get Task'),
              ),
            ),
          ),
          if (_sending)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: LinearProgressIndicator(
                value: _currentIndex / 20,
                backgroundColor: Colors.grey.shade300,
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                // Get tasks sorted by index
                final sortedTasks =
                    _tasks.entries
                        .where((entry) => entry.value != null)
                        .toList()
                      ..sort((a, b) => a.key.compareTo(b.key));

                if (index >= sortedTasks.length) {
                  return const SizedBox.shrink();
                }

                final taskEntry = sortedTasks[index];
                return _buildTaskCard(taskEntry.key, taskEntry.value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(int index, GetTask? task) {
    final hasData = task != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: hasData ? 2 : 1,
      color: Colors.white,
      child: InkWell(
        onTap: hasData ? () => _showTaskDetails(task) : null,
        splashColor: Colors.white,
        highlightColor: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Task Index: ${index + 1}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hasData ? Colors.black : Colors.grey.shade600,
                  ),
                ),
              ),
              if (hasData)
                const Icon(Icons.chevron_right, color: Color(0xFF008E46)),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskDetails(GetTask task) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Task Index: ${task.index + 1}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: Scrollbar(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDetailRow(
                          'Task Profile ID',
                          task.taskProfileId.toString(),
                        ),
                        _buildDetailRow('Start Date', task.startDate),
                        _buildDetailRow('End Date', task.endDate),
                        _buildDetailRow('Priority', task.priority.toString()),
                        _buildDetailRow(
                          'Cyclic Type',
                          _getCyclicTypeString(task.cyclicType),
                        ),
                        if (task.cyclicType == 4)
                          _buildDetailRow(
                            'Cyclic Time',
                            task.cyclicTime.toString(),
                          ),
                        _buildDetailRow(
                          'Off Days Mask',
                          task.offDaysMask.toString(),
                        ),
                        _buildDetailRow(
                          'Channel Number',
                          task.channelNumber.toString(),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Time Slots:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...task.timeSlots.asMap().entries.map((entry) {
                          final slotIndex = entry.key;
                          final slot = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Slot ${slotIndex + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildDetailRow('On Time', slot.onTime),
                                    _buildDetailRow('Off Time', slot.offTime),
                                    _buildDetailRow(
                                      'Value',
                                      slot.value.toString(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _sendAllTaskControlRequests(task),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF008E46),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text('Get Logs'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _showTaskLogs(task),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text('Show Logs'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCyclicTypeString(int cyclicType) {
    switch (cyclicType) {
      case 2:
        return 'Odd';
      case 3:
        return 'Even';
      case 4:
        return 'Cyclic';
      case 5:
        return 'Custom';
      default:
        return cyclicType.toString();
    }
  }

  String _getControlTypeString(int controlType) {
    switch (controlType) {
      case 1:
        return 'On';
      case 2:
        return 'Off';
      case 3:
        return 'Dim';
      case 4:
        return 'Autonomous Pass';
      case 5:
        return 'Error On';
      case 6:
        return 'Error Off';
      default:
        return controlType.toString();
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _sendAllTaskData() async {
    if (_sending) return;

    setState(() {
      _sending = true;
      _currentIndex = 0;
      _errorMessage = null;
      _successMessage = null;
      _tasks.clear();
    });

    try {
      final packets = TaskRequestHelper.createGetTaskData();

      for (int i = 0; i < packets.length; i++) {
        setState(() {
          _currentIndex = i;
        });

        await widget.rxCharacteristic.write(
          Uint8List.fromList(packets[i]),
          withoutResponse: widget.writeWithoutResponse,
        );

        // Her paket arasında 1 saniye bekleme
        if (i < packets.length - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (mounted) {
        setState(() {
          _sending = false;
          _successMessage =
              '20 task data packets sent successfully. Waiting for responses from device...';
        });
        // Clear success message after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _errorMessage = 'Send error: $e';
        });
        // Clear error message after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _errorMessage = null;
            });
          }
        });
      }
    }
  }

  Future<void> _sendAllTaskControlRequests(GetTask task) async {
    try {
      // Eski logları temizle
      final key = '${task.taskProfileId}_${task.channelNumber}';
      setState(() {
        _taskLogs.remove(key);
      });
      debugPrint('🗑️ Eski loglar temizlendi - Task Profile ID: ${task.taskProfileId}, Channel: ${task.channelNumber}');
      
      // Send requests for all 4 slots
      for (int slotNumber = 1; slotNumber <= 4; slotNumber++) {
        final packet = TaskRequestHelper.taskControlRequestData(
          taskProfileId: task.taskProfileId,
          channelNumber: task.channelNumber,
          slotNumber: slotNumber,
        );

        await widget.rxCharacteristic.write(
          Uint8List.fromList(packet),
          withoutResponse: widget.writeWithoutResponse,
        );

        // 1 saniye bekleme her istek arasında
        if (slotNumber < 4) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Get Logs requests sent for all slots'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending requests: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showTaskLogs(GetTask task) {
    final key = '${task.taskProfileId}_${task.channelNumber}';
    debugPrint('========================================');
    debugPrint('Show Logs - Filtering by:');
    debugPrint('Task Profile ID: ${task.taskProfileId}');
    debugPrint('Channel Number: ${task.channelNumber}');
    debugPrint('Key: $key');
    debugPrint('Total logs found: ${_taskLogs[key]?.length ?? 0}');
    debugPrint('========================================');
    final logs = _taskLogs[key] ?? [];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Task Control Logs',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Profile ID: ${task.taskProfileId}, Channel: ${task.channelNumber}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: Scrollbar(
                  child: logs.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'No logs available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: logs.map((log) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildDetailRow('Date', log.controlDate),
                                      _buildDetailRow('Time', log.controlTime),
                                      _buildDetailRow('Value', log.value.toString()),
                                      _buildDetailRow(
                                        'Control Type',
                                        _getControlTypeString(log.controlType),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
