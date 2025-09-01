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
    Key? key,
    required this.lead,
    this.requireSelection = false,
    this.onPitchSelected,
  }) : super(key: key);

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
    
    // Update on server
    final dataSource = ref.read(salesPitchDataSourceProvider);
    try {
      await dataSource.assignPitchToLead(widget.lead.id, pitchId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sales pitch selected'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save pitch selection'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
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
    final pitchesAsync = ref.watch(salesPitchesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        if (_isExpanded) ...[
          const SizedBox(height: 12),
          pitchesAsync.when(
            data: (pitches) => _buildPitchCards(pitches),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(
              'Error loading pitches: $error',
              style: TextStyle(color: AppTheme.errorRed),
            ),
          ),
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
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.requireSelection && _selectedPitchId == null) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(Required)',
                    style: TextStyle(
                      color: AppTheme.errorRed,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (_selectedPitchId != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
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

    // If a pitch is selected, show it prominently at the top
    if (_selectedPitchId != null) {
      final selectedPitch = pitches.firstWhere(
        (p) => p.id == _selectedPitchId,
        orElse: () => pitches.first,
      );
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected pitch display
          _buildSelectedPitchDisplay(selectedPitch),
          const SizedBox(height: 16),
          
          // Option to change pitch
          if (widget.lead.status == LeadStatus.new_ || widget.lead.status == LeadStatus.viewed) ...[
            Text(
              'Change Selection:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...pitches.where((p) => p.isActive && p.id != _selectedPitchId).map((pitch) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPitchCard(pitch),
            )).toList(),
          ],
        ],
      );
    }

    // No selection yet - show all pitches
    return Column(
      children: pitches.where((p) => p.isActive).map((pitch) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildPitchCard(pitch),
      )).toList(),
    );
  }
  
  Widget _buildSelectedPitchDisplay(SalesPitch pitch) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGold.withOpacity(0.15),
            AppTheme.primaryGold.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGold,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.primaryGold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Sales Pitch',
                        style: TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pitch.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pitch.attempts > 0) ...[
                  _buildStatChip(
                    '${pitch.conversionRate.toStringAsFixed(1)}%',
                    Icons.trending_up,
                    AppTheme.successGreen,
                  ),
                ],
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full pitch content (scrollable if long)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      pitch.content
                        .replaceAll('[Business Name]', widget.lead.businessName)
                        .replaceAll('[Location]', widget.lead.location),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Actions
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _copyToClipboard(pitch.content),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy to Clipboard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (pitch.attempts > 0) ...[
                      Text(
                        '${pitch.conversions} / ${pitch.attempts} converted',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPitchCard(SalesPitch pitch) {
    final isSelected = _selectedPitchId == pitch.id;
    
    return Container(
      decoration: BoxDecoration(
        color: isSelected 
          ? AppTheme.primaryGold.withOpacity(0.1)
          : Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected 
            ? AppTheme.primaryGold 
            : AppTheme.primaryGold.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and stats
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    pitch.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (pitch.attempts > 0) ...[
                  _buildStatChip(
                    '${pitch.conversionRate.toStringAsFixed(1)}%',
                    Icons.trending_up,
                    AppTheme.successGreen,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    '${pitch.attempts} calls',
                    Icons.phone,
                    AppTheme.accentPurple,
                  ),
                ],
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pitch.content
                    .replaceAll('[Business Name]', widget.lead.businessName)
                    .replaceAll('[Location]', widget.lead.location),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
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
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Select'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
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
                      icon: const Icon(Icons.copy, size: 16),
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

  Widget _buildStatChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 48,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No Sales Pitches Available',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please add at least 2 sales pitches in your account settings',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}