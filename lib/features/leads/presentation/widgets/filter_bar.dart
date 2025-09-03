import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../pages/leads_list_page.dart';
import 'primary_filter_row.dart';
import 'advanced_filter_section.dart';

class FilterBar extends ConsumerStatefulWidget {
  const FilterBar({super.key});

  @override
  ConsumerState<FilterBar> createState() => FilterBarState();
}

class FilterBarState extends ConsumerState<FilterBar> {
  final searchController = TextEditingController();
  Timer? debounceTimer;
  bool showFilters = false;

  @override
  void initState() {
    super.initState();
    searchController.addListener(() {
      setState(() {}); // Rebuild to update suffix icon visibility
    });
  }

  @override
  void dispose() {
    debounceTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: _buildSearchField(),
            ),
            // Primary Filters
            _buildPrimaryFilters(),
            // Filter Toggle
            _buildFilterToggle(),
            // Advanced Filters
            if (showFilters) _buildAdvancedFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: searchController,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.white,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: 'Search leads...',
        hintStyle: TextStyle(
          fontSize: 16,
          color: Colors.white.withOpacity(0.4),
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(
          CupertinoIcons.search,
          color: AppTheme.primaryGold,
          size: 20,
        ),
        suffixIcon: searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: Colors.white.withOpacity(0.3),
                  size: 18,
                ),
                onPressed: () {
                  searchController.clear();
                  ref.read(searchFilterProvider.notifier).state = '';
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.primaryGold),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      onChanged: (value) {
        debounceTimer?.cancel();
        debounceTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            ref.read(searchFilterProvider.notifier).state = value;
          }
        });
      },
    );
  }

  Widget _buildFilterToggle() {
    return GestureDetector(
      onTap: () => setState(() => showFilters = !showFilters),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              showFilters ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
              size: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Text(
              showFilters ? 'Hide Filters' : 'Show Filters',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryFilters() => const PrimaryFilterRow();
  Widget _buildAdvancedFilters() => const AdvancedFilterSection();
}