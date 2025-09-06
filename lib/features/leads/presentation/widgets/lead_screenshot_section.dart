import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class LeadScreenshotSection extends StatelessWidget {
  final String? screenshotPath;
  final VoidCallback? onScreenshotTap;

  const LeadScreenshotSection({
    super.key,
    this.screenshotPath,
    this.onScreenshotTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildScreenshotContainer(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.camera_alt,
          size: 20,
          color: AppTheme.accentPurple,
        ),
        const SizedBox(width: 8),
        Text(
          'Business Screenshot',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildScreenshotContainer() {
    return GestureDetector(
      onTap: screenshotPath != null ? onScreenshotTap : null,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: screenshotPath != null
              ? _buildScreenshotImage()
              : _buildNoScreenshotPlaceholder('No screenshot available for this lead'),
        ),
      ),
    );
  }

  Widget _buildScreenshotImage() {
    return Image.network(
      'http://localhost:8000/screenshots/$screenshotPath',
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            color: AppTheme.accentPurple,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildNoScreenshotPlaceholder('Failed to load screenshot');
      },
    );
  }

  Widget _buildNoScreenshotPlaceholder(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Screenshots are captured for new leads during automation',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}