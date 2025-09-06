import 'package:flutter/material.dart';
import '../../../domain/entities/lead_timeline_entry.dart';
import 'timeline_color_scheme.dart';
import 'timeline_icon_mapper.dart';

class TimelineEntryForm extends StatefulWidget {
  final Function(TimelineEntryType, String, DateTime?) onSubmit;
  final VoidCallback onCancel;
  final TimelineEntryType? initialType;
  final String? initialContent;
  final DateTime? initialFollowUpDate;

  const TimelineEntryForm({
    super.key,
    required this.onSubmit,
    required this.onCancel,
    this.initialType,
    this.initialContent,
    this.initialFollowUpDate,
  });

  @override
  State<TimelineEntryForm> createState() => _TimelineEntryFormState();
}

class _TimelineEntryFormState extends State<TimelineEntryForm> {
  late TimelineEntryType _selectedType;
  late TextEditingController _contentController;
  DateTime? _followUpDate;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? TimelineEntryType.note;
    _contentController = TextEditingController(text: widget.initialContent);
    _followUpDate = widget.initialFollowUpDate;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TimelineColorScheme.getBackgroundColor(_selectedType),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TimelineColorScheme.getBorderColor(_selectedType),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTypeSelector(),
          const SizedBox(height: 16),
          _buildContentField(),
          if (_showFollowUpOption()) ...[
            const SizedBox(height: 16),
            _buildFollowUpDatePicker(context),
          ],
          const SizedBox(height: 16),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TimelineEntryType>(
          value: _selectedType,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          items: TimelineEntryType.values.map((type) {
            final icon = TimelineIconMapper.getEntryIcon(type);
            final label = TimelineIconMapper.getEntryLabel(type);
            final color = TimelineColorScheme.getEntryColor(type);
            
            return DropdownMenuItem(
              value: type,
              child: Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              ),
            );
          }).toList(),
          onChanged: (type) {
            if (type != null) {
              setState(() {
                _selectedType = type;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildContentField() {
    return TextField(
      controller: _contentController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Enter ${TimelineIconMapper.getEntryLabel(_selectedType).toLowerCase()} details...',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: TimelineColorScheme.getEntryColor(_selectedType),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildFollowUpDatePicker(BuildContext context) {
    return InkWell(
      onTap: () => _selectFollowUpDate(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              size: 18,
              color: TimelineColorScheme.getEntryColor(_selectedType),
            ),
            const SizedBox(width: 8),
            Text(
              _followUpDate != null
                  ? 'Follow up: ${_formatDate(_followUpDate!)}'
                  : 'Set follow-up date (optional)',
              style: TextStyle(
                color: _followUpDate != null ? Colors.black : Colors.grey,
              ),
            ),
            const Spacer(),
            if (_followUpDate != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  setState(() {
                    _followUpDate = null;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _contentController.text.isNotEmpty ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: TimelineColorScheme.getEntryColor(_selectedType),
          ),
          child: const Text('Add Entry'),
        ),
      ],
    );
  }

  bool _showFollowUpOption() {
    return _selectedType == TimelineEntryType.followUp ||
           _selectedType == TimelineEntryType.reminder ||
           _selectedType == TimelineEntryType.meeting;
  }

  Future<void> _selectFollowUpDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_followUpDate ?? DateTime.now()),
      );

      if (time != null) {
        setState(() {
          _followUpDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _submit() {
    widget.onSubmit(
      _selectedType,
      _contentController.text,
      _followUpDate,
    );
  }
}