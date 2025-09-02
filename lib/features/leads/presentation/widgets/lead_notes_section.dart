import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';

class LeadNotesSection extends StatefulWidget {
  const LeadNotesSection({Key? key}) : super(key: key);

  @override
  State<LeadNotesSection> createState() => _LeadNotesSectionState();
}

class _LeadNotesSectionState extends State<LeadNotesSection> {
  final _notesController = TextEditingController();
  final _notesFocusNode = FocusNode();
  bool _isEditingNotes = false;
  String _salesPitch = '';

  @override
  void initState() {
    super.initState();
    _loadSalesPitch();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSalesPitch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _salesPitch = prefs.getString('sales_pitch') ?? _getDefaultSalesPitch();
    });
  }

  String _getDefaultSalesPitch() {
    return "Hi [Business Name], I noticed you don't have a website yet. "
           "I help small businesses like yours get online with professional "
           "websites that bring in more customers. Would you be interested "
           "in a quick 5-minute chat about how this could help your business?";
  }

  void _startEditingNotes() {
    setState(() => _isEditingNotes = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notesFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.notes,
              size: 20,
              color: AppTheme.accentCyan,
            ),
            const SizedBox(width: 8),
            Text(
              'Notes',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _startEditingNotes,
              icon: const Icon(Icons.edit, size: 18),
              color: AppTheme.accentCyan,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isEditingNotes)
          _buildEditingField()
        else
          _buildDisplayField(),
      ],
    );
  }

  Widget _buildEditingField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.accentCyan.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _notesController,
            focusNode: _notesFocusNode,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add your notes here...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              fillColor: Colors.transparent,
              filled: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _isEditingNotes = false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.6),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveNotes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayField() {
    return GestureDetector(
      onTap: _startEditingNotes,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.elevatedSurface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Text(
          _notesController.text.isNotEmpty 
              ? _notesController.text 
              : 'Tap to add notes...',
          style: TextStyle(
            color: _notesController.text.isNotEmpty 
                ? Colors.white.withOpacity(0.9)
                : Colors.white.withOpacity(0.3),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _saveNotes() {
    setState(() => _isEditingNotes = false);
  }
}