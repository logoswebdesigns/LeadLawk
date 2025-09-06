import 'package:flutter/material.dart';
import '../../../domain/entities/lead_timeline_entry.dart';
import 'timeline_color_scheme.dart';
import 'timeline_icon_mapper.dart';
import 'github_formatter.dart';

class TimelineEntryWidget extends StatelessWidget {
  final LeadTimelineEntry entry;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TimelineEntryWidget({
    super.key,
    required this.entry,
    this.isFirst = false,
    this.isLast = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = TimelineColorScheme.getEntryColor(entry.type);
    final icon = TimelineIconMapper.getEntryIcon(entry.type);
    final label = TimelineIconMapper.getEntryLabel(entry.type);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimelineIndicator(color),
        const SizedBox(width: 16),
        Expanded(
          child: _buildEntryCard(context, color, icon, label),
        ),
      ],
    );
  }

  Widget _buildTimelineIndicator(Color color) {
    return Column(
      children: [
        if (!isFirst)
          Container(
            width: 2,
            height: 20,
            color: color.withValues(alpha: 0.3),
          ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
        ),
        if (!isLast)
          Container(
            width: 2,
            height: 60,
            color: color.withValues(alpha: 0.3),
          ),
      ],
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    Color color,
    IconData icon,
    String label,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: TimelineColorScheme.getBorderColor(entry.type),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: TimelineColorScheme.getBackgroundColor(entry.type),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const Spacer(),
                Text(
                  GitHubFormatter.formatDate(entry.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                if (onEdit != null || onDelete != null) ...[
                  const SizedBox(width: 8),
                  _buildActions(context),
                ],
              ],
            ),
            if (entry.title.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
            if (entry.description != null && entry.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.description!,
                style: const TextStyle(fontSize: 13),
              ),
            ],
            if (entry.followUpDate != null) ...[
              const SizedBox(height: 8),
              _buildFollowUpChip(color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFollowUpChip(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            'Follow up: ${GitHubFormatter.formatFullDate(entry.followUpDate!)}',
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 16, color: Colors.grey[600]),
      itemBuilder: (context) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 16),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 16, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
      onSelected: (value) {
        if (value == 'edit' && onEdit != null) {
          onEdit!();
        } else if (value == 'delete' && onDelete != null) {
          onDelete!();
        }
      },
    );
  }
}