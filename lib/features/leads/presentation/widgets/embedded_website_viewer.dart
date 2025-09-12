import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../utils/lead_detail_utils.dart';

class EmbeddedWebsiteViewer extends StatefulWidget {
  final Lead lead;
  final double height;

  const EmbeddedWebsiteViewer({
    super.key,
    required this.lead,
    this.height = 600,
  });

  @override
  State<EmbeddedWebsiteViewer> createState() => _EmbeddedWebsiteViewerState();
}

class _EmbeddedWebsiteViewerState extends State<EmbeddedWebsiteViewer> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  double _loadingProgress = 0.0;
  String _currentUrl = '';
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    if (widget.lead.websiteUrl == null || widget.lead.websiteUrl!.isEmpty) {
      setState(() {
        _errorMessage = 'No website available';
        _isLoading = false;
      });
      return;
    }

    String url = widget.lead.websiteUrl!;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    _currentUrl = url;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress / 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
              _currentUrl = url;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            _updateNavigationState();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Failed to load website: ${error.description}';
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation within the same domain
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1')
      ..loadRequest(Uri.parse(url));
  }

  Future<void> _updateNavigationState() async {
    final canGoBack = await _controller.canGoBack();
    final canGoForward = await _controller.canGoForward();
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (widget.lead.websiteUrl == null || widget.lead.websiteUrl!.isEmpty) {
      return _buildNoWebsiteState();
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Browser toolbar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.elevatedSurface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Navigation buttons
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, size: 18),
                  onPressed: _canGoBack
                      ? () async {
                          await _controller.goBack();
                          _updateNavigationState();
                        }
                      : null,
                  color: AppTheme.primaryGold,
                  disabledColor: Colors.white.withValues(alpha: 0.3),
                  constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.all(6),
                  tooltip: 'Go back',
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, size: 18),
                  onPressed: _canGoForward
                      ? () async {
                          await _controller.goForward();
                          _updateNavigationState();
                        }
                      : null,
                  color: AppTheme.primaryGold,
                  disabledColor: Colors.white.withValues(alpha: 0.3),
                  constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.all(6),
                  tooltip: 'Go forward',
                ),
                IconButton(
                  icon: Icon(Icons.refresh, size: 18),
                  onPressed: () => _controller.reload(),
                  color: AppTheme.primaryGold,
                  constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.all(6),
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 8),
                // URL display
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: _currentUrl.startsWith('https')
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _currentUrl,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Open in browser button
                IconButton(
                  icon: Icon(Icons.open_in_new, size: 18),
                  onPressed: () {
                    if (widget.lead.websiteUrl != null) {
                      String url = widget.lead.websiteUrl!;
                      if (!url.startsWith('http')) {
                        url = 'https://$url';
                      }
                      // Use the existing utility to open in browser
                      LeadDetailUtils.openWebsite(url);
                    }
                  },
                  color: AppTheme.primaryGold,
                  constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.all(6),
                  tooltip: 'Open in browser',
                ),
              ],
            ),
          ),
          // Loading progress bar
          if (_isLoading)
            LinearProgressIndicator(
              value: _loadingProgress,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
              minHeight: 2,
            ),
          // WebView content
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              child: WebViewWidget(controller: _controller),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoWebsiteState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.language_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No Website Available',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This lead does not have a website URL',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'Website Loading Error',
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage ?? 'Unable to load website',
                style: TextStyle(
                  color: Colors.red.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _initializeWebView,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}