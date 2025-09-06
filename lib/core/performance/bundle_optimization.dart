// Bundle size optimization utilities.
// Pattern: Optimization Pattern - reducing app size.
// Single Responsibility: Bundle and asset optimization.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bundle optimizer for reducing app size
class BundleOptimizer {
  /// Remove debug code in release builds
  static T releaseOnly<T>(T Function() callback, T defaultValue) {
    if (kReleaseMode) {
      return callback();
    }
    return defaultValue;
  }
  
  /// Include code only in debug mode
  static T? debugOnly<T>(T Function() callback) {
    if (kDebugMode) {
      return callback();
    }
    return null;
  }
  
  /// Profile mode only code
  static T? profileOnly<T>(T Function() callback) {
    if (kProfileMode) {
      return callback();
    }
    return null;
  }
  
  /// Conditional asset loading based on platform
  static String getOptimizedAssetPath(String basePath) {
    final extension = basePath.split('.').last;
    final nameWithoutExtension = basePath.substring(0, basePath.lastIndexOf('.'));
    
    // Use WebP for web, PNG for others
    if (kIsWeb && (extension == 'png' || extension == 'jpg')) {
      return '$nameWithoutExtension.webp';
    }
    
    return basePath;
  }
  
  /// Load asset with size optimization
  static Future<String> loadOptimizedAsset(String path) async {
    try {
      // Try loading compressed version first
      final compressedPath = '$path.gz';
      return await rootBundle.loadString(compressedPath);
    } catch (_) {
      // Fall back to original
      return await rootBundle.loadString(path);
    }
  }
}

/// Asset optimizer for images and resources
class AssetOptimizer {
  /// Get resolution-aware asset
  static String getResolutionAwareAsset(
    String basePath,
    double devicePixelRatio,
  ) {
    final extension = basePath.split('.').last;
    final nameWithoutExtension = basePath.substring(0, basePath.lastIndexOf('.'));
    
    String suffix = '';
    if (devicePixelRatio >= 3.0) {
      suffix = '@3x';
    } else if (devicePixelRatio >= 2.0) {
      suffix = '@2x';
    }
    
    return '$nameWithoutExtension$suffix.$extension';
  }
  
  /// Get platform-optimized asset format
  static String getPlatformOptimizedFormat(String basePath) {
    if (!kIsWeb) return basePath;
    
    // Use modern formats for web
    final formats = {
      '.png': '.webp',
      '.jpg': '.webp',
      '.jpeg': '.webp',
      '.gif': '.webp',
    };
    
    for (final entry in formats.entries) {
      if (basePath.endsWith(entry.key)) {
        return basePath.replaceAll(entry.key, entry.value);
      }
    }
    
    return basePath;
  }
}

/// Dead code elimination helpers
class DeadCodeEliminator {
  /// Feature flag based code inclusion
  static const bool _featureA = true;
  static const bool _featureB = false;
  
  static T? includeIfFeature<T>(
    String featureName,
    T Function() callback,
  ) {
    final features = {
      'featureA': _featureA,
      'featureB': _featureB,
    };
    
    if (features[featureName] ?? false) {
      return callback();
    }
    return null;
  }
  
  /// Platform-specific code inclusion
  static T? includeForPlatform<T>(
    TargetPlatform platform,
    T Function() callback,
  ) {
    // This will be tree-shaken on other platforms
    if (defaultTargetPlatform == platform) {
      return callback();
    }
    return null;
  }
}

/// Minification helpers for reducing code size
class MinificationHelper {
  /// Short names for production
  static const bool _useShortNames = kReleaseMode;
  
  /// Get minified class name
  static String className(String fullName) {
    if (!_useShortNames) return fullName;
    
    // In production, use short names
    final hash = fullName.hashCode.toRadixString(36);
    return 'C$hash';
  }
  
  /// Get minified property name
  static String propertyName(String fullName) {
    if (!_useShortNames) return fullName;
    
    // In production, use short names
    final hash = fullName.hashCode.toRadixString(36);
    return 'p$hash';
  }
}

/// Tree shaking annotations
class TreeShaking {
  /// Mark code as shakeable
  static const shakeable = pragma('vm:entry-point');
  
  /// Prevent tree shaking
  static const keep = pragma('vm:keep');
  
  /// Platform specific shaking
  static const webOnly = pragma('dart2js:noInline');
  static const mobileOnly = pragma('vm:prefer-inline');
}

/// Bundle size analyzer
class BundleSizeAnalyzer {
  static final Map<String, int> _componentSizes = {};
  
  /// Track component size
  static void trackComponentSize(String componentName, int sizeInBytes) {
    _componentSizes[componentName] = sizeInBytes;
  }
  
  /// Get size report
  static Map<String, dynamic> getSizeReport() {
    final totalSize = _componentSizes.values.fold<int>(0, (a, b) => a + b);
    
    final sortedComponents = _componentSizes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return {
      'totalSize': totalSize,
      'totalSizeKB': totalSize / 1024,
      'totalSizeMB': totalSize / 1024 / 1024,
      'componentCount': _componentSizes.length,
      'largestComponents': sortedComponents.take(10).map((e) => {
        'name': e.key,
        'size': e.value,
        'sizeKB': e.value / 1024,
        'percentage': (e.value / totalSize * 100).toStringAsFixed(2),
      }).toList(),
    };
  }
  
  /// Clear tracked sizes
  static void clear() {
    _componentSizes.clear();
  }
}

/// Optimization directives for build
class OptimizationDirectives {
  /// Compiler optimization hints
  static const alwaysInline = pragma('vm:always-inline');
  static const neverInline = pragma('vm:never-inline');
  
  /// Dart2JS optimizations
  static const noInline = pragma('dart2js:noInline');
  static const tryInline = pragma('dart2js:tryInline');
  
  /// AOT optimizations
  static const entryPoint = pragma('vm:entry-point');
  static const preferInline = pragma('vm:prefer-inline');
}