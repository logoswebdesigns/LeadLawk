// Adaptive scaffold for different screen sizes.
// Pattern: Adapter Pattern - adapts layout to screen size.
// Single Responsibility: Screen-size adaptive scaffolding.

import 'package:flutter/material.dart';
import 'responsive_builder.dart';

/// Navigation item for adaptive scaffold
class AdaptiveNavigationItem {
  final IconData icon;
  final String label;
  final Widget page;
  final IconData? selectedIcon;
  
  const AdaptiveNavigationItem({
    required this.icon,
    required this.label,
    required this.page,
    this.selectedIcon,
  });
}

/// Adaptive scaffold that changes layout based on screen size
class AdaptiveScaffold extends StatefulWidget {
  final List<AdaptiveNavigationItem> destinations;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;
  final int initialIndex;
  final ValueChanged<int>? onDestinationSelected;
  
  const AdaptiveScaffold({
    super.key,
    required this.destinations,
    this.floatingActionButton,
    this.appBar,
    this.initialIndex = 0,
    this.onDestinationSelected,
  });
  
  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  late int _selectedIndex;
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }
  
  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    widget.onDestinationSelected?.call(index);
  }
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobile: (context, constraints) => _buildMobileLayout(),
      tablet: (context, constraints) => _buildTabletLayout(),
      desktop: (context, constraints) => _buildDesktopLayout(),
    );
  }
  
  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: widget.appBar,
      body: IndexedStack(
        index: _selectedIndex,
        children: widget.destinations.map((d) => d.page).toList(),
      ),
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: widget.destinations.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: item.selectedIcon != null 
              ? Icon(item.selectedIcon!) 
              : null,
            label: item.label,
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildTabletLayout() {
    return Scaffold(
      appBar: widget.appBar,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            labelType: NavigationRailLabelType.selected,
            destinations: widget.destinations.map((item) {
              return NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: item.selectedIcon != null 
                  ? Icon(item.selectedIcon!) 
                  : null,
                label: Text(item.label),
              );
            }).toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: widget.destinations.map((d) => d.page).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
  
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          NavigationDrawer(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            children: [
              if (widget.appBar != null)
                const DrawerHeader(
                  child: const Text('Menu'),
                ),
              ...widget.destinations.map((item) {
                return NavigationDrawerDestination(
                  icon: Icon(item.icon),
                  selectedIcon: item.selectedIcon != null 
                    ? Icon(item.selectedIcon!) 
                    : null,
                  label: Text(item.label),
                );
              }),
            ],
          ),
          Expanded(
            child: Scaffold(
              appBar: widget.appBar,
              body: IndexedStack(
                index: _selectedIndex,
                children: widget.destinations.map((d) => d.page).toList(),
              ),
              floatingActionButton: widget.floatingActionButton,
            ),
          ),
        ],
      ),
    );
  }
}

/// Master-detail layout for tablets and desktop
class MasterDetailScaffold extends StatefulWidget {
  final Widget Function(BuildContext context, int? selectedId) masterBuilder;
  final Widget Function(BuildContext context, int selectedId) detailBuilder;
  final Widget emptyDetail;
  final double masterWidth;
  final int? initialSelectedId;
  
  const MasterDetailScaffold({
    super.key,
    required this.masterBuilder,
    required this.detailBuilder,
    required this.emptyDetail,
    this.masterWidth = 320,
    this.initialSelectedId,
  });
  
  @override
  State<MasterDetailScaffold> createState() => _MasterDetailScaffoldState();
}

class _MasterDetailScaffoldState extends State<MasterDetailScaffold> {
  int? _selectedId;
  
  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedId;
  }
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobile: (context, constraints) => _buildMobileLayout(),
      tablet: (context, constraints) => _buildSplitLayout(constraints),
      desktop: (context, constraints) => _buildSplitLayout(constraints),
    );
  }
  
  Widget _buildMobileLayout() {
    if (_selectedId != null) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () {
              setState(() {
                _selectedId = null;
              });
            },
          ),
        ),
        body: widget.detailBuilder(context, _selectedId!),
      );
    }
    
    return Scaffold(
      body: widget.masterBuilder(context, _selectedId),
    );
  }
  
  Widget _buildSplitLayout(BoxConstraints constraints) {
    return Row(
      children: [
        SizedBox(
        width: widget.masterWidth,
          child: widget.masterBuilder(context, _selectedId),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _selectedId != null
            ? widget.detailBuilder(context, _selectedId!)
            : widget.emptyDetail,
        ),
      ],
    );
  }
}