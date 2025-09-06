import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/sales_pitch_provider.dart';

class LeadSalesPitchSection extends ConsumerStatefulWidget {
  final Lead lead;
  final bool requireSelection;
  final Function(String pitchId)? onPitchSelected;

  const LeadSalesPitchSection({
    super.key,
    required this.lead,
    this.requireSelection = false,
    this.onPitchSelected,
  });

  @override
  ConsumerState<LeadSalesPitchSection> createState() => _LeadSalesPitchSectionState();
}

class _LeadSalesPitchSectionState extends ConsumerState<LeadSalesPitchSection> {
  bool _isExpanded = false;
  String? _selectedPitchId;

  @override
  void initState() {
    super.initState();
    _selectedPitchId = widget.lead.salesPitchId;
    // Auto-expand if selection is required and no pitch selected
    // OR if a pitch is already selected (so it's visible)
    if ((widget.requireSelection && _selectedPitchId == null) || _selectedPitchId != null) {
      _isExpanded = true;
    }
  }

  void _selectPitch(String pitchId) async {
    setState(() {
      _selectedPitchId = pitchId;
    });
    
    // Notify parent widget
    widget.onPitchSelected?.call(pitchId);
  }

  @override
  Widget build(BuildContext context) {
    final pitches = ref.watch(salesPitchesProvider);

    if (pitches.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.elevatedSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.requireSelection 
              ? AppTheme.primaryGold.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
            width: widget.requireSelection ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            'No sales pitches available. Add them in account settings.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Find selected pitch
    SalesPitch? selectedPitch;
    if (_selectedPitchId != null) {
      try {
        selectedPitch = pitches.firstWhere((p) => p.id == _selectedPitchId);
      } catch (_) {
        // Pitch not found
      }
    }

    // If no pitch selected and we require selection, auto-select default
    if (selectedPitch == null && widget.requireSelection) {
      try {
        selectedPitch = pitches.firstWhere((p) => p.isDefault);
        _selectedPitchId = selectedPitch.id;
        // Notify parent
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onPitchSelected?.call(selectedPitch!.id);
        });
      } catch (_) {
        // No default pitch
        if (pitches.isNotEmpty) {
          selectedPitch = pitches.first;
          _selectedPitchId = selectedPitch.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onPitchSelected?.call(selectedPitch!.id);
          });
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.requireSelection && _selectedPitchId == null
                  ? AppTheme.primaryGold.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
                width: widget.requireSelection && _selectedPitchId == null ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                // Header
                Padding(padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.campaign,
                        color: widget.requireSelection && _selectedPitchId == null
                          ? AppTheme.primaryGold
                          : Colors.white.withValues(alpha: 0.7),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sales Pitch',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            if (selectedPitch != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                selectedPitch.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryGold,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else if (widget.requireSelection) ...[
                              const SizedBox(height: 4),
                              const Text(
                                'Select a pitch before calling',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.warningOrange,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 24,
                      ),
                    ],
                  ),
                ),

                // Expanded Content
                if (_isExpanded) ...[
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Selected Pitch Content
                          if (selectedPitch != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGold.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.primaryGold.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          selectedPitch.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryGold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.copy,
                                          size: 16,
                                          color: Colors.white.withValues(alpha: 0.5),
                                        ),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: selectedPitch!.content));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Pitch copied to clipboard'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        tooltip: 'Copy pitch',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    selectedPitch.content,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.9),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          
                          // Other Available Pitches
                          if (pitches.length > 1) ...[
                            Text(
                              'Other Pitches',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...pitches.where((p) => p.id != _selectedPitchId).map((pitch) => 
                              Padding(padding: const EdgeInsets.only(bottom: 8),
                                child: _buildPitchOption(pitch),
                              ),
                            ),
                          ] else if (_selectedPitchId == null) ...[
                            // Show all pitches if none selected
                            ...pitches.map((pitch) => 
                              Padding(padding: const EdgeInsets.only(bottom: 8),
                                child: _buildPitchOption(pitch),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPitchOption(SalesPitch pitch) {
    final isSelected = pitch.id == _selectedPitchId;
    
    return Material(
      color: isSelected 
        ? AppTheme.primaryGold.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _selectPitch(pitch.id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected 
                ? AppTheme.primaryGold.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pitch.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppTheme.primaryGold : Colors.white,
                      ),
                    ),
                  ),
                  if (pitch.isDefault) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withValues(alpha: 0.2),
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
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                pitch.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}