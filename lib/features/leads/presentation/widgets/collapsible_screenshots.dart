import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../domain/entities/lead.dart';
import 'unified_screenshot_card.dart';

class CollapsibleScreenshots extends StatefulWidget {
  final Lead lead;
  final bool defaultExpanded;
  
  const CollapsibleScreenshots({
    Key? key,
    required this.lead,
    this.defaultExpanded = true,
  }) : super(key: key);
  
  @override
  State<CollapsibleScreenshots> createState() => _CollapsibleScreenshotsState();
}

class _CollapsibleScreenshotsState extends State<CollapsibleScreenshots> 
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  
  @override
  void initState() {
    super.initState();
    _isExpanded = widget.defaultExpanded;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final hasWebsiteScreenshot = widget.lead.hasWebsite && 
                                 widget.lead.websiteScreenshotPath != null;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.photo_on_rectangle,
                    size: 20,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Screenshots',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildScreenshotsContent(
                isMobile, 
                isDesktop, 
                hasWebsiteScreenshot,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScreenshotsContent(
    bool isMobile, 
    bool isDesktop, 
    bool hasWebsiteScreenshot,
  ) {
    // For mobile: Stack screenshots vertically
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Google Maps Screenshot Card
          AspectRatio(
            aspectRatio: 16 / 9,
            child: UnifiedScreenshotCard(
              screenshotPath: widget.lead.screenshotPath,
              type: ScreenshotType.googleMaps,
              lead: widget.lead,
              showInCard: true,
            ),
          ),
          if (hasWebsiteScreenshot) ...[
            const SizedBox(height: 12),
            // Website Screenshot Card
            AspectRatio(
              aspectRatio: 16 / 9,
              child: UnifiedScreenshotCard(
                screenshotPath: widget.lead.websiteScreenshotPath,
                type: ScreenshotType.website,
                lead: widget.lead,
                showInCard: true,
              ),
            ),
          ],
        ],
      );
    }
    
    // For desktop/tablet: Side by side
    return SizedBox(
      height: isDesktop ? 400 : 300,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Google Maps Screenshot
          Expanded(
            flex: hasWebsiteScreenshot ? 1 : 2,
            child: UnifiedScreenshotCard(
              screenshotPath: widget.lead.screenshotPath,
              type: ScreenshotType.googleMaps,
              lead: widget.lead,
              showInCard: true,
            ),
          ),
          // Website Screenshot if available
          if (hasWebsiteScreenshot) ...[
            const SizedBox(width: 16),
            Expanded(
              child: UnifiedScreenshotCard(
                screenshotPath: widget.lead.websiteScreenshotPath,
                type: ScreenshotType.website,
                lead: widget.lead,
                showInCard: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}