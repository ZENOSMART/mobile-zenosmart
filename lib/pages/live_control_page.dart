import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../helpers/channel_icon_helper.dart';
import '../helpers/live_control_data_helper.dart';
import '../repositories/device_channel_templates_repository.dart';

class LiveControlPage extends StatefulWidget {
  const LiveControlPage({
    super.key,
    required this.deviceId,
    required this.rxCharacteristic,
    required this.writeWithoutResponse,
    this.deviceName,
    this.initialChannelValues,
  });

  final String deviceId;
  final BluetoothCharacteristic rxCharacteristic;
  final bool writeWithoutResponse;
  final String? deviceName;
  final Map<int, double>? initialChannelValues;

  @override
  State<LiveControlPage> createState() => _LiveControlPageState();
}

class _LiveControlPageState extends State<LiveControlPage> {
  final _channelRepo = const DeviceChannelTemplatesRepository();
  final _timeoutController = TextEditingController(text: '1');
  final List<_ChannelControl> _controls = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  bool _hasChannelOne = false;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  @override
  void dispose() {
    for (final control in _controls) {
      control.dispose();
    }
    _timeoutController.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _channelRepo.getWriteChannelsByDeviceId(
        widget.deviceId,
      );

      final controls = rows
          .map((row) {
            final channelCode = row['channel_code'] as int?;
            double? initialValue;
            if (channelCode != null && widget.initialChannelValues != null) {
              initialValue = widget.initialChannelValues![channelCode];
            }
            return _ChannelControl.fromRow(row, initialValue: initialValue);
          })
          .where((control) => control.isValid)
          .toList();

      if (controls.isEmpty) {
        setState(() {
          _hasChannelOne = false;
          _controls.clear();
          _error = 'No controllable channel found for this device.';
          _loading = false;
        });
        return;
      }

      setState(() {
        for (final control in _controls) {
          control.dispose();
        }
        _controls
          ..clear()
          ..addAll(controls);
        _hasChannelOne = _controls.any((c) => c.channelCode == 1);
        if (_hasChannelOne) {
          _timeoutController.text = '5';
        } else if ((_timeoutController.text).trim().isEmpty) {
          _timeoutController.text = '1';
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _hasChannelOne = false;
        _error = 'Channels could not be loaded: $e';
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    if (_sending) return;

    try {
      final timeoutMinutes = _hasChannelOne
          ? 5
          : (_parseTimeoutMinutes(_timeoutController.text.trim()));

      final values = <String, dynamic>{};

      for (final control in _controls) {
        final value = control.currentValue;
        if (value == null) {
          throw Exception(
            'Please enter a valid value for ${control.displayName}.',
          );
        }
        values[control.rowId] = value;
        debugPrint(
          '[LiveControl] Kanal ${control.channelCode} (${control.displayName}) => $value',
        );
      }

      setState(() => _sending = true);

      final packet = await LiveControlDataHelper.handleLiveControlData(
        deviceId: widget.deviceId,
        channelValues: values,
        timeoutValue: timeoutMinutes,
      );

      await widget.rxCharacteristic.write(
        packet,
        withoutResponse: widget.writeWithoutResponse,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Command sent.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not be sent: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  int _parseTimeoutMinutes(String raw) {
    final parsed = int.tryParse(raw);
    if (parsed == null) return 1;
    return parsed.clamp(1, 60);
  }

  Color _resolveIconColor(_ChannelControl control) {
    if (control.channelCode == 1) {
      final value = control.normalizedValue ?? 0;
      return _getDimIconColor(value);
    }
    return Colors.blue.shade700;
  }

  Color _getDimIconColor(double value) {
    final clampedValue = value.clamp(0.0, 100.0);
    final percentage = clampedValue / 100.0;

    if (percentage <= 0.5) {
      final localPercentage = percentage * 2;
      return Color.lerp(
        Colors.grey.shade700,
        Colors.orange.shade600,
        localPercentage,
      )!;
    } else {
      final localPercentage = (percentage - 0.5) * 2;
      return Color.lerp(
        Colors.orange.shade600,
        Colors.yellow.shade600,
        localPercentage,
      )!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.deviceName ?? 'Live Control')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._controls.map(_buildControlCard),
        if (!_hasChannelOne) ...[
          const SizedBox(height: 12),
          _buildTimeoutField(),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008E46),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _sending ? null : _send,
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
            label: Text(_sending ? 'Sending...' : 'Send'),
          ),
        ),
      ],
    );
  }

  Widget _buildControlCard(_ChannelControl control) {
    final icon = ChannelIconHelper.getIcon(control.channelCode);
    final iconColor = _resolveIconColor(control);
    final showInlineToggle = control.isOnOff;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Icon(icon, size: 24, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        control.displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showInlineToggle) ...[
                  const SizedBox(width: 12),
                  Switch(
                    value: control.isOnState,
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF008E46),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey.shade400,
                    trackOutlineColor: MaterialStateProperty.resolveWith(
                      (states) => Colors.transparent,
                    ),
                    onChanged: (value) {
                      setState(() {
                        control.setOnOff(value);
                      });
                    },
                  ),
                ],
              ],
            ),
            if (!showInlineToggle) ...[
              const SizedBox(height: 12),
              control.buildInputWidget(context, () => setState(() {})),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeoutField() {
    final isDisabled = _hasChannelOne;
    final timeoutValue = _parseTimeoutMinutes(_timeoutController.text.trim());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Text(
              'Timeout (dk)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF008E46),
                  inactiveTrackColor: const Color(0xFF008E46).withOpacity(0.2),
                  thumbColor: const Color(0xFF008E46),
                  overlayColor: const Color(0xFF008E46).withOpacity(0.1),
                ),
                child: Slider(
                  value: timeoutValue.toDouble(),
                  min: 1,
                  max: 60,
                  divisions: 59,
                  onChanged: isDisabled
                      ? null
                      : (value) {
                          final clamped = value.round().clamp(1, 60);
                          _timeoutController.text = clamped.toString();
                          setState(() {});
                        },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$timeoutValue dk',
              style: TextStyle(
                color: isDisabled ? Colors.grey : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelControl {
  _ChannelControl({
    required this.rowId,
    required this.channelCode,
    required this.dataType,
    required this.dataByteLength,
    required this.displayName,
    this.min,
    this.max,
    this.isBoolean = false,
    this.isOnOff = false,
    this.initialValue,
  }) {
    if (!isValid) return;
    if (isBoolean || isOnOff) {
      if (initialValue != null) {
        boolValue = initialValue! >= 0.5;
      } else {
        boolValue = false;
      }
    } else if (_useSlider) {
      final minVal = (min ?? 0).toDouble();
      final maxVal = (max ?? 100).toDouble();
      if (initialValue != null) {
        sliderValue = initialValue!.clamp(minVal, maxVal).toDouble();
      } else {
        sliderValue = minVal;
      }
    } else {
      final initialText = initialValue != null
          ? (dataType.contains('int') || dataType.contains('byte')
                ? initialValue!.toStringAsFixed(0)
                : initialValue!.toString())
          : (min != null
                ? (dataType.contains('int') || dataType.contains('byte')
                      ? min!.toStringAsFixed(0)
                      : min!.toString())
                : '');
      textController = TextEditingController(text: initialText);
    }
  }

  factory _ChannelControl.fromRow(
    Map<String, Object?> row, {
    double? initialValue,
  }) {
    final rowId = row['id'] as String?;
    final channelCode = row['channel_code'] as int?;
    if (rowId == null || channelCode == null) {
      return _ChannelControl._invalid();
    }

    final dataType = (row['data_type'] as String? ?? 'byte').toLowerCase();
    final minValue = (row['data_limit_min'] as num?)?.toDouble();
    final maxValue = (row['data_limit_max'] as num?)?.toDouble();
    final dataByteLength = row['data_byte_length'] as int? ?? 1;
    final displayName = (row['en_name'] as String?)?.trim().isNotEmpty == true
        ? row['en_name'] as String
        : 'Channel $channelCode';

    final isBoolean = dataType == 'bool' || dataType == 'boolean';
    final isOnOff = !isBoolean && minValue == 0 && maxValue == 1;

    return _ChannelControl(
      rowId: rowId,
      channelCode: channelCode,
      dataType: dataType,
      dataByteLength: dataByteLength,
      displayName: displayName,
      min: minValue,
      max: maxValue,
      isBoolean: isBoolean,
      isOnOff: isOnOff,
      initialValue: initialValue,
    );
  }

  _ChannelControl._invalid()
    : rowId = '',
      channelCode = -1,
      dataType = 'invalid',
      dataByteLength = 0,
      displayName = '',
      min = null,
      max = null,
      isBoolean = false,
      isOnOff = false,
      initialValue = null;

  final String rowId;
  final int channelCode;
  final String dataType;
  final int dataByteLength;
  final String displayName;
  final double? min;
  final double? max;
  final bool isBoolean;
  final bool isOnOff;
  final double? initialValue;

  double? sliderValue;
  TextEditingController? textController;
  bool? boolValue;

  bool get isValid => channelCode >= 0;

  bool get _useSlider =>
      !isBoolean && !isOnOff && min == 0 && max == 100 && dataByteLength <= 2;

  bool get isOnState => boolValue ?? false;

  double? get normalizedValue {
    if (_useSlider) {
      final value = sliderValue ?? (min ?? 0);
      return value.toDouble();
    }
    if (isBoolean || isOnOff) {
      return (boolValue ?? false) ? 100.0 : 0.0;
    }
    if (initialValue != null) return initialValue;
    if (min != null) return min;
    return null;
  }

  Widget buildInputWidget(BuildContext context, VoidCallback refresh) {
    if (isBoolean) {
      return Row(
        children: [
          const Text('Status'),
          const Spacer(),
          Switch(
            value: boolValue ?? false,
            onChanged: (value) {
              boolValue = value;
              refresh();
            },
            trackOutlineColor: MaterialStateProperty.resolveWith(
              (states) => Colors.transparent,
            ),
          ),
        ],
      );
    }

    if (isOnOff) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Status'),
          Switch(
            value: boolValue ?? false,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF008E46),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade400,
            trackOutlineColor: MaterialStateProperty.resolveWith(
              (states) => Colors.transparent,
            ),
            onChanged: (value) {
              boolValue = value;
              refresh();
            },
          ),
        ],
      );
    }

    if (_useSlider) {
      final divisions = ((max ?? 100) - (min ?? 0)).toInt();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF008E46),
              inactiveTrackColor: const Color(0xFF008E46).withOpacity(0.2),
              thumbColor: const Color(0xFF008E46),
              overlayColor: const Color(0xFF008E46).withOpacity(0.1),
            ),
            child: Slider(
              value: sliderValue ?? (min ?? 0),
              min: min ?? 0,
              max: max ?? 100,
              divisions: divisions > 0 ? divisions : null,
              label: (sliderValue ?? 0).toStringAsFixed(0),
              onChanged: (value) {
                sliderValue = value;
                refresh();
              },
            ),
          ),
          Text(
            'Selected value: ${(sliderValue ?? 0).toStringAsFixed(0)}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: textController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'Enter value',
            helperText: _buildHelperText(),
          ),
          onChanged: (_) => refresh(),
        ),
      ],
    );
  }

  String? _buildHelperText() {
    if (min == null && max == null) return null;
    return 'Range: ${min ?? '-'} - ${max ?? '-'}';
  }

  dynamic get currentValue {
    if (isBoolean || isOnOff) {
      return boolValue ?? false;
    }

    if (_useSlider) {
      return sliderValue != null ? sliderValue!.round() : null;
    }

    final raw = textController?.text.trim();
    if (raw == null || raw.isEmpty) return null;

    final number = double.tryParse(raw);
    if (number == null) return null;

    if (dataType.contains('int') || dataType.contains('byte')) {
      return number.toInt();
    }

    return number;
  }

  void dispose() {
    textController?.dispose();
  }

  void toggleOnOff() {
    boolValue = !(boolValue ?? false);
  }

  void setOnOff(bool value) {
    boolValue = value;
  }
}
