import 'package:flutter/material.dart';
import '../../../domain/entities/lead_timeline_entry.dart';
import 'timeline_color_scheme.dart';
import 'timeline_icon_mapper.dart';

class TimelineFilterBar extends StatelessWidget {
  final Set<TimelineEntryType> selectedTypes;
  final Function(Set<TimelineEntryType>) onFilterChanged;

  const TimelineFilterBar({
    super.key,
    required this.selectedTypes,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip(
            context,
            'All',
            selectedTypes.isEmpty,
            () => onFilterChanged({}),
            Colors.grey,
          ),
          const SizedBox(width: 8),
          ...TimelineEntryType.values.map((type) {
            return Padding(padding: const EdgeInsets.only(right: 8),
              child: _buildTypeFilterChip(context, type),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChip(BuildContext context, TimelineEntryType type) {
    final isSelected = selectedTypes.contains(type);
    final color = TimelineColorScheme.getEntryColor(type);
    final icon = TimelineIconMapper.getEntryIcon(type);
    final label = TimelineIconMapper.getEntryLabel(type);

    return _buildFilterChip(
      context,
      label,
      isSelected,
      () {
        final newSet = Set<TimelineEntryType>.from(selectedTypes);
        if (isSelected) {
          newSet.remove(type);
        } else {
          newSet.add(type);
        }
        onFilterChanged(newSet);
      },
      color,
      icon,
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
    Color color, [
    IconData? icon,
  ]) {
    return FilterChip(
      selected: isSelected,
      onSelected: (_) => onTap(),
      avatar: icon != null
          ? Icon(icon, size: 16, color: isSelected ? Colors.white : color)
          : null,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.white : color,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      selectedColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}