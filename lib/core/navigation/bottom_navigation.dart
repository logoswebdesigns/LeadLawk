import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final String currentPath;
  
  const AppBottomNavigationBar({
    super.key,
    required this.currentPath,
  });

  int _getSelectedIndex() {
    if (currentPath.startsWith('/leads')) {
      return 0;
    } else if (currentPath.startsWith('/browser')) {
      return 1;
    } else if (currentPath.startsWith('/analytics')) {
      return 2;
    } else if (currentPath.startsWith('/account')) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: 72,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context: context,
                icon: Icons.list_alt_rounded,
                label: 'Leads',
                index: 0,
                path: '/leads',
              ),
              _buildNavItem(
                context: context,
                icon: Icons.add_circle_outline,
                label: 'Find Leads',
                index: 1,
                path: '/browser',
                isCenter: true,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.insights,
                label: 'Analytics',
                index: 2,
                path: '/analytics',
              ),
              _buildNavItem(
                context: context,
                icon: Icons.person_outline,
                label: 'Account',
                index: 3,
                path: '/account',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required String path,
    bool isCenter = false,
  }) {
    final isSelected = _getSelectedIndex() == index;
    
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isSelected) {
              context.go(path);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected && isCenter
                  ? AppTheme.primaryGold.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.all(isCenter ? 6 : 3),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isCenter 
                            ? AppTheme.primaryGold 
                            : AppTheme.primaryGold.withValues(alpha: 0.1))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(isCenter ? 14 : 6),
                  ),
                  child: Icon(
                    icon,
                    size: isCenter ? 26 : 22,
                    color: isSelected
                        ? (isCenter ? AppTheme.backgroundDark : AppTheme.primaryGold)
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppTheme.primaryGold
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}