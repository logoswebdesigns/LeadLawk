// Code splitting and deferred loading.
// Pattern: Lazy Loading Pattern for code modules.
// Single Responsibility: Code bundle optimization.

import 'package:flutter/material.dart';

/// Deferred route loader
class DeferredRoute {
  final String name;
  final Future<Widget> Function() loader;
  final Widget Function()? loadingWidget;
  final Widget Function(Object error)? errorWidget;
  
  const DeferredRoute({
    required this.name,
    required this.loader,
    this.loadingWidget,
    this.errorWidget,
  });
}

/// Route builder for deferred loading
class DeferredRouteBuilder extends StatelessWidget {
  final DeferredRoute route;
  
  const DeferredRouteBuilder({
    super.key,
    required this.route,
  });
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: route.loader(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return route.loadingWidget?.call() ?? 
            const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
        }
        
        if (snapshot.hasError) {
          return route.errorWidget?.call(snapshot.error!) ??
            Scaffold(
              body: Center(
                child: Text('Error loading module: ${snapshot.error}'),
              ),
            );
        }
        
        return snapshot.data ?? SizedBox.shrink();
      },
    );
  }
}

/// Module loader for feature splitting
class ModuleLoader {
  static final Map<String, dynamic> _loadedModules = {};
  static final Map<String, Future<dynamic>> _loadingModules = {};
  
  /// Load a module lazily
  static Future<T> loadModule<T>(
    String moduleId,
    Future<T> Function() loader,
  ) async {
    // Return if already loaded
    if (_loadedModules.containsKey(moduleId)) {
      return _loadedModules[moduleId] as T;
    }
    
    // Wait if currently loading
    if (_loadingModules.containsKey(moduleId)) {
      return await _loadingModules[moduleId] as T;
    }
    
    // Start loading
    final future = loader();
    _loadingModules[moduleId] = future;
    
    try {
      final module = await future;
      _loadedModules[moduleId] = module;
      _loadingModules.remove(moduleId);
      return module;
    } catch (e) {
      _loadingModules.remove(moduleId);
      rethrow;
    }
  }
  
  /// Preload modules in background
  static Future<void> preloadModules(
    List<String> moduleIds,
    Map<String, Future<dynamic> Function()> loaders,
  ) async {
    final futures = moduleIds.map((id) {
      final loader = loaders[id];
      if (loader != null) {
        return loadModule(id, loader);
      }
      return Future.value();
    });
    
    await Future.wait(futures);
  }
  
  /// Clear loaded modules
  static void clearModules([List<String>? moduleIds]) {
    if (moduleIds == null) {
      _loadedModules.clear();
    } else {
      for (final id in moduleIds) {
        _loadedModules.remove(id);
      }
    }
  }
  
  /// Get module stats
  static Map<String, dynamic> getModuleStats() {
    return {
      'loadedCount': _loadedModules.length,
      'loadingCount': _loadingModules.length,
      'loadedModules': _loadedModules.keys.toList(),
      'loadingModules': _loadingModules.keys.toList(),
    };
  }
}

/// Lazy widget that loads on demand
class LazyWidget extends StatefulWidget {
  final Future<Widget> Function() builder;
  final Widget placeholder;
  final bool preload;
  final Duration? delay;
  
  const LazyWidget({
    super.key,
    required this.builder,
    required this.placeholder,
    this.preload = false,
    this.delay,
  });
  
  @override
  State<LazyWidget> createState() => _LazyWidgetState();
}

class _LazyWidgetState extends State<LazyWidget> {
  Future<Widget>? _widgetFuture;
  
  @override
  void initState() {
    super.initState();
    if (widget.preload) {
      _loadWidget();
    }
  }
  
  void _loadWidget() {
    _widgetFuture = Future.delayed(
      widget.delay ?? Duration.zero,
      widget.builder,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_widgetFuture == null) {
      // Not loaded yet, show placeholder
      return GestureDetector(
        onTap: () {
          setState(() {
            _loadWidget();
          });
        },
        child: widget.placeholder,
      );
    }
    
    return FutureBuilder<Widget>(
      future: _widgetFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        return widget.placeholder;
      },
    );
  }
}

/// Tree-shaking helper for conditional imports
class ConditionalImport {
  /// Load platform-specific implementation
  static T getPlatformImplementation<T>({
    required T Function() mobile,
    required T Function() web,
    required T Function() desktop,
  }) {
    if (identical(0, 0.0)) {
      // Running on web
      return web();
    } else if (Platform.isAndroid || Platform.isIOS) {
      return mobile();
    } else {
      return desktop();
    }
  }
  
  /// Load feature based on configuration
  static T? getFeatureImplementation<T>(
    String featureName,
    Map<String, T Function()> implementations,
  ) {
    final implementation = implementations[featureName];
    return implementation?.call();
  }
}

// Platform stub for web compatibility
class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isWindows => false;
  static bool get isMacOS => false;
  static bool get isLinux => false;
}

/// Widget pool for recycling expensive widgets
class WidgetPool<T extends Widget> {
  final List<T> _available = [];
  final List<T> _inUse = [];
  final T Function() _factory;
  final int maxSize;
  
  WidgetPool({
    required T Function() factory,
    this.maxSize = 10,
  }) : _factory = factory;
  
  T acquire() {
    T widget;
    
    if (_available.isNotEmpty) {
      widget = _available.removeLast();
    } else if (_inUse.length < maxSize) {
      widget = _factory();
    } else {
      // Pool is full, create anyway but don't track
      return _factory();
    }
    
    _inUse.add(widget);
    return widget;
  }
  
  void release(T widget) {
    if (_inUse.remove(widget)) {
      _available.add(widget);
    }
  }
  
  void clear() {
    _available.clear();
    _inUse.clear();
  }
  
  Map<String, int> getStats() {
    return {
      'available': _available.length,
      'inUse': _inUse.length,
      'total': _available.length + _inUse.length,
      'maxSize': maxSize,
    };
  }
}