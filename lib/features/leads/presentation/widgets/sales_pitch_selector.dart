import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/sales_pitch_provider.dart';

class SalesPitchSelector extends ConsumerStatefulWidget {
  final Lead lead;
  final bool isRequired;
  final Function(String pitchId)? onPitchSelected;
  
  const SalesPitchSelector({
    super.key,
    required this.lead,
    this.isRequired = false,
    this.onPitchSelected,
  });

  @override
  ConsumerState<SalesPitchSelector> createState() => _SalesPitchSelectorState();
}

class _SalesPitchSelectorState extends ConsumerState<SalesPitchSelector> {
  String? _selectedPitchId;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedPitchId = widget.lead.salesPitchId;
  }

  void _selectPitch(String pitchId) {
    setState(() {
      _selectedPitchId = pitchId;
    });
    widget.onPitchSelected?.call(pitchId);
  }

  void _copyToClipboard(String content) {
    final personalizedContent = content
        .replaceAll('[Business Name]', widget.lead.businessName)
        .replaceAll('[Location]', widget.lead.location);
    
    Clipboard.setData(ClipboardData(text: personalizedContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sales pitch copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pitches = ref.watch(salesPitchesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        if (_isExpanded) ...[
          const SizedBox(height: 12),
          _buildPitchCards(pitches),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Row(
        children: [
          Icon(
            Icons.campaign,
            size: 20,
            color: AppTheme.primaryGold,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Text(
                  'Sales Pitch',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.isRequired) ...[
                  const SizedBox(width: 4),
                  const Text(
                    '*',
                    style: TextStyle(
                      color: AppTheme.errorRed,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_selectedPitchId != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Selected',
                      style: TextStyle(
                        color: AppTheme.successGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            color: AppTheme.primaryGold,
          ),
        ],
      ),
    );
  }

  Widget _buildPitchCards(List<SalesPitch> pitches) {
    if (pitches.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: pitches.map((pitch) => Padding(padding: EdgeInsets.only(bottom: 12),
        child: _buildPitchCard(pitch),
      )).toList(),
    );
  }

  Widget _buildPitchCard(SalesPitch pitch) {
    final isSelected = _selectedPitchId == pitch.id;
    
    return Container(
      decoration: BoxDecoration(
        color: isSelected 
          ? AppTheme.primaryGold.withValues(alpha: 0.1)
          : Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected 
            ? AppTheme.primaryGold 
            : AppTheme.primaryGold.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and stats
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    pitch.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pitch.content
                    .replaceAll('[Business Name]', widget.lead.businessName)
                    .replaceAll('[Location]', widget.lead.location),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.5,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Actions
                Row(
                  children: [
                    if (!isSelected)
                      ElevatedButton.icon(
                        onPressed: () => _selectPitch(pitch.id),
                        icon: Icon(Icons.check_circle),
                        label: const Text('Select'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: AppTheme.successGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Selected',
                              style: TextStyle(
                                color: AppTheme.successGreen,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _copyToClipboard(pitch.content),
                      icon: Icon(Icons.copy),
                      label: const Text('Copy'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.accentPurple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.campaign,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No Sales Pitches Available',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please add at least 2 sales pitches in your account settings',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}