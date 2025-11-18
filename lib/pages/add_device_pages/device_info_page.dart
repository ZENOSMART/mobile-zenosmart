import 'package:flutter/material.dart';
import '../add_device_form_page.dart';
import '../map_pick_page.dart';

class DeviceInfoPage extends StatefulWidget {
  const DeviceInfoPage({
    super.key,
    required this.draft,
    required this.onDraftUpdated,
  });

  final AddDeviceDraft draft;
  final Function(AddDeviceDraft) onDraftUpdated;

  @override
  State<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage> {
  static const _accentColor = Color(0xFF008E46);
  static const _fieldHeight = 56.0;
  static const _fieldLabelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draft.name);
    _locationController = TextEditingController(text: widget.draft.location);
    _lat = widget.draft.latitude;
    _lng = widget.draft.longitude;
    _latController = TextEditingController(
      text: _lat?.toStringAsFixed(6) ?? '',
    );
    _lngController = TextEditingController(
      text: _lng?.toStringAsFixed(6) ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  double? _parseCoordinate(String value) {
    final normalized = value.replaceAll(',', '.').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  void _updateDraft() {
    final draft = widget.draft
      ..name = _nameController.text.trim()
      ..location = _locationController.text.trim()
      ..latitude = _lat
      ..longitude = _lng;
    widget.onDraftUpdated(draft);
  }

  Future<void> _pickLocation() async {
    final res = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(
        builder: (_) => MapPickPage(initialLat: _lat, initialLng: _lng),
      ),
    );
    if (res != null) {
      setState(() {
        _lat = res.latitude;
        _lng = res.longitude;
        _locationController.text = res.address ?? _locationController.text;
        _latController.text = _lat?.toStringAsFixed(6) ?? '';
        _lngController.text = _lng?.toStringAsFixed(6) ?? '';
      });
      _updateDraft();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _buildTextField(
            controller: _nameController,
            label: 'Device Name',
            onChanged: (_) => _updateDraft(),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _locationController,
            label: 'Location',
            onChanged: (_) => _updateDraft(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _latController,
                  label: 'Latitude',
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  onChanged: (value) {
                    final parsed = _parseCoordinate(value);
                    setState(() => _lat = parsed);
                    _updateDraft();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _lngController,
                  label: 'Longitude',
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  onChanged: (value) {
                    final parsed = _parseCoordinate(value);
                    setState(() => _lng = parsed);
                    _updateDraft();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: _fieldHeight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontSize: 16),
              ),
              onPressed: _pickLocation,
              icon: const Icon(Icons.map, size: 22),
              label: const Text('Select From Map'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? hintText,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _fieldLabelStyle),
        const SizedBox(height: 6),
        SizedBox(
          height: _fieldHeight,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: _buildInputDecoration(hintText: hintText),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
