import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/sales_pitch_provider.dart';

class SalesPitchModal extends ConsumerStatefulWidget {
  const SalesPitchModal({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const SalesPitchModal(),
    );
  }

  @override
  ConsumerState<SalesPitchModal> createState() => _SalesPitchModalState();
}

class _SalesPitchModalState extends ConsumerState<SalesPitchModal> {
  SalesPitch? _selectedPitch;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _contentController;
  late TextEditingController _descriptionController;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _contentController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _startEditing(SalesPitch? pitch) {
    setState(() {
      _isEditing = true;
      _selectedPitch = pitch;
      if (pitch != null) {
        _nameController.text = pitch.name;
        _contentController.text = pitch.content;
        _descriptionController.text = pitch.description ?? '';
        _isDefault = pitch.isDefault;
      } else {
        _nameController.clear();
        _contentController.clear();
        _descriptionController.clear();
        _isDefault = false;
      }
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _selectedPitch = null;
      _nameController.clear();
      _contentController.clear();
      _descriptionController.clear();
      _isDefault = false;
    });
  }

  Future<void> _savePitch() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(salesPitchesProvider.notifier);
    
    if (_selectedPitch != null) {
      // Update existing pitch
      final updated = _selectedPitch!.copyWith(
        name: _nameController.text.trim(),
        content: _contentController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        isDefault: _isDefault,
        updatedAt: DateTime.now(),
      );
      await notifier.updatePitch(_selectedPitch!.id, updated);
    } else {
      // Create new pitch
      final newPitch = SalesPitch(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        content: _contentController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        isDefault: _isDefault,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notifier.addPitch(newPitch);
    }
    
    _cancelEditing();
  }

  Future<void> _deletePitch(String id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.elevatedSurface,
        title: const Text('Delete Sales Pitch?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this sales pitch? This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (shouldDelete == true) {
      await ref.read(salesPitchesProvider.notifier).deletePitch(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pitches = ref.watch(salesPitchesProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    if (_isEditing) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: _cancelEditing,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        _isEditing 
                          ? (_selectedPitch != null ? 'Edit Sales Pitch' : 'New Sales Pitch')
                          : 'Sales Pitch Templates',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_isEditing) ...[
                      TextButton(
                        onPressed: _savePitch,
                        child: Text(
                          _selectedPitch != null ? 'Save' : 'Create',
                          style: const TextStyle(
                            color: AppTheme.primaryGold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ] else ...[
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGold),
                        onPressed: () => _startEditing(null),
                        tooltip: 'Add New Pitch',
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Content
              Flexible(
                child: _isEditing
                  ? _buildEditForm()
                  : _buildPitchesList(pitches),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPitchesList(List<SalesPitch> pitches) {
    if (pitches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 64,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No sales pitches yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button to create your first pitch',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort pitches to put default first
    final sortedPitches = List<SalesPitch>.from(pitches);
    sortedPitches.sort((a, b) {
      if (a.isDefault) return -1;
      if (b.isDefault) return 1;
      return 0;
    });

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: sortedPitches.length,
      itemBuilder: (context, index) {
        final pitch = sortedPitches[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: pitch.isDefault
              ? Border.all(color: AppTheme.primaryGold, width: 2)
              : null,
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: pitch.isDefault, // Auto-expand default pitch
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              pitch.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (pitch.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGold.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'DEFAULT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryGold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (pitch.description != null && pitch.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            pitch.description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.5)),
                    color: AppTheme.elevatedSurface,
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          _startEditing(pitch);
                          break;
                        case 'setDefault':
                          await ref.read(salesPitchesProvider.notifier).setDefault(pitch.id);
                          break;
                        case 'delete':
                          await _deletePitch(pitch.id);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20, color: Colors.white70),
                            SizedBox(width: 12),
                            Text('Edit', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      if (!pitch.isDefault)
                        const PopupMenuItem(
                          value: 'setDefault',
                          child: Row(
                            children: [
                              Icon(Icons.star, size: 20, color: AppTheme.primaryGold),
                              SizedBox(width: 12),
                              Text('Set as Default', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      if (sortedPitches.length > 1)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pitch.content,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Updated ${_formatDate(pitch.updatedAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _startEditing(pitch),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryGold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Pitch Name *',
                hintText: 'e.g., Professional Web Services',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryGold),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name for this pitch';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Brief description of when to use this pitch',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryGold),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              style: const TextStyle(color: Colors.white),
              maxLines: 10,
              decoration: InputDecoration(
                labelText: 'Sales Pitch Content *',
                hintText: 'Enter your sales pitch here...',
                alignLabelWithHint: true,
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryGold),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the pitch content';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Set as Default Pitch',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'This pitch will be selected by default when making calls',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
                value: _isDefault,
                onChanged: (value) {
                  setState(() {
                    _isDefault = value;
                  });
                },
                activeColor: AppTheme.primaryGold,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: Keep your pitch concise and personalized. Mention specific benefits and include a clear call to action.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}