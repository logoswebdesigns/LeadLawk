import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';

enum ScreenshotType { googleMaps, website }

class UnifiedScreenshotCard extends StatelessWidget {
  final String? screenshotPath;
  final ScreenshotType type;
  final Lead? lead; // Optional for website-specific features
  final VoidCallback? onTap;
  final bool showInCard; // Whether to show in a card container
  
  const UnifiedScreenshotCard({
    super.key,
    required this.screenshotPath,
    required this.type,
    this.lead,
    this.onTap,
    this.showInCard = true,
  });
  
  @override
  Widget build(BuildContext context) {
    if (!showInCard) {
      return _buildImageOnly(context);
    }
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Expanded(
            child: _buildImageSection(context),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
    final isWebsite = type == ScreenshotType.website;
    final icon = isWebsite ? Icons.web : Icons.location_on;
    final title = isWebsite ? 'Website Preview' : 'Google Maps Listing';
    final color = isWebsite ? AppTheme.successGreen : AppTheme.primaryBlue;
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                if (type == ScreenshotType.website && lead?.websiteUrl != null)
                  Text(
                    lead!.websiteUrl!.replaceAll(RegExp(r'https?://'), ''),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // PageSpeed badge for website screenshots
          if (type == ScreenshotType.website && lead?.pagespeedMobileScore != null)
            _buildScoreBadge(lead!.pagespeedMobileScore!),
        ],
      ),
    );
  }
  
  Widget _buildImageSection(BuildContext context) {
    return GestureDetector(
      onTap: screenshotPath != null ? (onTap ?? () => _showFullScreenshot(context)) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (screenshotPath != null)
              _buildImage(context)
            else
              _buildPlaceholder(context),
            
            // Tap to expand overlay (only if image exists)
            if (screenshotPath != null)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fullscreen,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'View',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImageOnly(BuildContext context) {
    if (screenshotPath == null) {
      return _buildPlaceholder(context);
    }
    
    return GestureDetector(
      onTap: onTap ?? () => _showFullScreenshot(context),
      child: _buildImage(context),
    );
  }
  
  Widget _buildImage(BuildContext context) {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
    final folder = type == ScreenshotType.website ? 'website_screenshots' : 'screenshots';
    final imageUrl = '$baseUrl/$folder/$screenshotPath';
    
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            color: type == ScreenshotType.website 
                ? AppTheme.successGreen 
                : AppTheme.primaryBlue,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildErrorState(context);
      },
    );
  }
  
  Widget _buildPlaceholder(BuildContext context) {
    final icon = type == ScreenshotType.website 
        ? Icons.language 
        : Icons.location_off;
    final message = type == ScreenshotType.website
        ? 'No website screenshot available'
        : 'No Google Maps screenshot available';
    
    return Container(
      color: AppTheme.backgroundDark.withValues(alpha: 0.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorState(BuildContext context) {
    return Container(
      color: AppTheme.backgroundDark.withValues(alpha: 0.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 48,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 8),
          Text(
            'Failed to load image',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScoreBadge(int score) {
    final color = _getScoreColor(score);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.speed,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            score.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getScoreColor(int score) {
    if (score >= 90) return AppTheme.successGreen;
    if (score >= 50) return AppTheme.warningOrange;
    return AppTheme.errorRed;
  }
  
  void _showFullScreenshot(BuildContext context) {
    if (screenshotPath == null) return;
    
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
    final folder = type == ScreenshotType.website ? 'website_screenshots' : 'screenshots';
    final imageUrl = '$baseUrl/$folder/$screenshotPath';
    
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: Hero(
                  tag: 'screenshot_${type.name}_$screenshotPath',
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              floatingActionButton: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.black54,
                onPressed: () => Navigator.of(context).pop(),
                child: Icon(Icons.refresh),
              ),
            ),
          );
        },
      ),
    );
  }
}