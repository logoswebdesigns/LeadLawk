// Image optimization and caching system.
// Pattern: Cache-Aside Pattern with lazy loading.
// Single Responsibility: Image performance optimization.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Optimized image widget with caching and lazy loading
class OptimizedImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext context, Widget child, ImageChunkEvent?)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final int? cacheWidth;
  final int? cacheHeight;
  final Duration fadeInDuration;
  final bool enableMemoryCache;
  
  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.loadingBuilder,
    this.errorBuilder,
    this.cacheWidth,
    this.cacheHeight,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.enableMemoryCache = true,
  });
  
  @override
  State<OptimizedImage> createState() => _OptimizedImageState();
}

class _OptimizedImageState extends State<OptimizedImage> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.enableMemoryCache;
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Image.network(
      widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth ?? _calculateCacheSize(widget.width),
      cacheHeight: widget.cacheHeight ?? _calculateCacheSize(widget.height),
      loadingBuilder: widget.loadingBuilder ?? _defaultLoadingBuilder,
      errorBuilder: (context, error, stackTrace) {
        return widget.errorBuilder?.call(context, error) ??
            _defaultErrorWidget();
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: widget.fadeInDuration,
          curve: Curves.easeOut,
          child: child,
        );
      },
    );
  }
  
  int? _calculateCacheSize(double? size) {
    if (size == null) return null;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    return (size * pixelRatio).round();
  }
  
  Widget _defaultLoadingBuilder(
    BuildContext context,
    Widget child,
    ImageChunkEvent? loadingProgress,
  ) {
    if (loadingProgress == null) {
      return child;
    }
    
    final progress = loadingProgress.expectedTotalBytes != null
        ? loadingProgress.cumulativeBytesLoaded / 
          loadingProgress.expectedTotalBytes!
        : null;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: widget.width,
          height: widget.height,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        CircularProgressIndicator(
          value: progress,
          strokeWidth: 2,
        ),
      ],
    );
  }
  
  Widget _defaultErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Theme.of(context).colorScheme.errorContainer,
      child: Icon(
        Icons.broken_image,
        color: Theme.of(context).colorScheme.onErrorContainer,
      ),
    );
  }
}

/// Progressive image loading (blur hash → low res → high res)
class ProgressiveImage extends StatefulWidget {
  final String thumbnailUrl;
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Duration transitionDuration;
  
  const ProgressiveImage({
    super.key,
    required this.thumbnailUrl,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.transitionDuration = const Duration(milliseconds: 500),
  });
  
  @override
  State<ProgressiveImage> createState() => _ProgressiveImageState();
}

class _ProgressiveImageState extends State<ProgressiveImage> {
  bool _isHighResLoaded = false;
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // Low resolution thumbnail
        Image.network(
          widget.thumbnailUrl,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          cacheWidth: 50,
          cacheHeight: 50,
        ),
        
        // High resolution image with fade
        AnimatedOpacity(
          opacity: _isHighResLoaded ? 1.0 : 0.0,
          duration: widget.transitionDuration,
          child: Image.network(
            widget.imageUrl,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (frame != null && !_isHighResLoaded) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _isHighResLoaded = true);
                  }
                });
              }
              return child;
            },
          ),
        ),
      ],
    );
  }
}

/// Image cache manager
class ImageCacheManager {
  static final ImageCacheManager _instance = ImageCacheManager._internal();
  factory ImageCacheManager() => _instance;
  ImageCacheManager._internal();
  
  final Map<String, Uint8List> _memoryCache = {};
  
  /// Precache images
  Future<void> precacheImages(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    final futures = imageUrls.map((url) {
      return precacheImage(NetworkImage(url), context);
    });
    
    await Future.wait(futures);
  }
  
  /// Clear cache
  void clearCache() {
    _memoryCache.clear();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
  
  /// Set cache size limits
  void configureCacheLimits({
    int? maximumSize,
    int? maximumSizeBytes,
  }) {
    final imageCache = PaintingBinding.instance.imageCache;
    
    if (maximumSize != null) {
      imageCache.maximumSize = maximumSize;
    }
    
    if (maximumSizeBytes != null) {
      imageCache.maximumSizeBytes = maximumSizeBytes;
    }
  }
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final imageCache = PaintingBinding.instance.imageCache;
    
    return {
      'currentSize': imageCache.currentSize,
      'currentSizeBytes': imageCache.currentSizeBytes,
      'maximumSize': imageCache.maximumSize,
      'maximumSizeBytes': imageCache.maximumSizeBytes,
      'liveImageCount': imageCache.liveImageCount,
      'pendingImageCount': imageCache.pendingImageCount,
    };
  }
}

/// Lazy loading image in viewport
class LazyImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget placeholder;
  
  const LazyImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    required this.placeholder,
  });
  
  @override
  State<LazyImage> createState() => _LazyImageState();
}

class _LazyImageState extends State<LazyImage> {
  bool _isVisible = false;
  
  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      onVisibilityChanged: (info) {
        if (!_isVisible && info.visibleFraction > 0) {
          setState(() => _isVisible = true);
        }
      },
      child: _isVisible
          ? OptimizedImage(
              imageUrl: widget.imageUrl,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
            )
          : widget.placeholder,
    );
  }
}

/// Visibility detector widget
class VisibilityDetector extends StatefulWidget {
  final Widget child;
  final Function(VisibilityInfo) onVisibilityChanged;
  
  const VisibilityDetector({
    super.key,
    required this.child,
    required this.onVisibilityChanged,
  });
  
  @override
  State<VisibilityDetector> createState() => _VisibilityDetectorState();
}

class _VisibilityDetectorState extends State<VisibilityDetector> {
  @override
  Widget build(BuildContext context) {
    // Simplified implementation - in production use visibility_detector package
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onVisibilityChanged(VisibilityInfo(visibleFraction: 1.0));
    });
    
    return widget.child;
  }
}

class VisibilityInfo {
  final double visibleFraction;
  
  VisibilityInfo({required this.visibleFraction});
}