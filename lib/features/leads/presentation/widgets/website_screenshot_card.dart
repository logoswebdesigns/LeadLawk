import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';

class WebsiteScreenshotCard extends StatelessWidget {
  final Lead lead;
  
  const WebsiteScreenshotCard({
    super.key,
    required this.lead,
  });
  
  @override
  Widget build(BuildContext context) {
    if (lead.websiteScreenshotPath == null) {
      return SizedBox.shrink();
    }
    
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
    final imageUrl = '$baseUrl/website_screenshots/${lead.websiteScreenshotPath}';
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.elevatedSurface,
            AppTheme.elevatedSurface.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryGold.withValues(alpha: 0.1),
                  AppTheme.primaryGold.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.phone_iphone,
                    size: 18,
                    color: AppTheme.primaryGold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mobile Website Preview',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (lead.websiteUrl != null)
                        Text(
                          lead.websiteUrl!.replaceAll(RegExp(r'https?://'), ''),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (lead.pagespeedMobileScore != null) ...[
                  _buildScoreBadge(lead.pagespeedMobileScore!),
                ],
              ],
            ),
          ),
          
          // Enhanced Screenshot with Device Frame
          GestureDetector(
            onTap: () {
              _showFullWebsiteScreenshot(context, lead.websiteScreenshotPath!);
            },
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.backgroundDark.withValues(alpha: 0.6),
                    AppTheme.backgroundDark.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 9 / 16, // Mobile phone aspect ratio
                      child: Stack(
                        children: [
                          // Background
                          Container(
                            color: Colors.white,
                          ),
                          
                          // Screenshot Image
                          Positioned.fill(
                            child: Hero(
                              tag: 'website_screenshot_${lead.websiteScreenshotPath}',
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: AppTheme.backgroundDark,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.wifi_off_rounded,
                                          size: 48,
                                          color: Colors.white.withValues(alpha: 0.3),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Failed to load',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                  
                          // Coming Soon Warning Overlay
                          if (_mightBeComingSoon(lead))
                            Positioned(
                              top: 8,
                              left: 8,
                              right: 8,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningOrange.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Possible placeholder page',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          // Tap hint at bottom
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.touch_app,
                                      size: 14,
                                      color: AppTheme.primaryGold,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tap to expand',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.primaryGold.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScoreBadge(int score) {
    final color = _getScoreColor(score);
    final IconData icon = score >= 90 
        ? Icons.speed 
        : score >= 50 
            ? Icons.timer 
            : Icons.warning_amber_rounded;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            score.toString(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  bool _mightBeComingSoon(Lead lead) {
    // Detect potential "coming soon" pages:
    // High PageSpeed score + no phone number might indicate placeholder page
    final hasHighScore = (lead.pagespeedMobileScore ?? 0) > 85;
    final hasNoPhone = lead.phone.isEmpty || lead.phone == 'No phone';
    // A "coming soon" page typically loads very fast due to minimal content
    final hasLowLCP = (lead.pagespeedLargestContentfulPaint ?? 9999) < 2.0;
    
    return hasHighScore && (hasNoPhone || hasLowLCP);
  }
  
  Color _getScoreColor(int score) {
    if (score >= 90) return AppTheme.successGreen;
    if (score >= 50) return AppTheme.warningOrange;
    return AppTheme.errorRed;
  }
  
  void _showFullWebsiteScreenshot(BuildContext context, String screenshotPath) {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
    final imageUrl = '$baseUrl/website_screenshots/$screenshotPath';
    
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
                  tag: 'website_screenshot_$screenshotPath',
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