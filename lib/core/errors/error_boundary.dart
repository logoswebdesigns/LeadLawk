// Error boundary widgets for graceful error handling in UI.
// Pattern: Error Boundary - catch and display errors in widget tree.
// Single Responsibility: Prevent error propagation in UI.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_exceptions.dart';
import 'error_handler.dart';

/// Error boundary widget
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(AppException error, VoidCallback retry)? errorBuilder;
  final void Function(AppException error)? onError;
  final bool showDefaultError;
  
  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
    this.showDefaultError = true,
  });
  
  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  AppException? _error;
  final ErrorHandler _errorHandler = ErrorHandler();
  
  @override
  void initState() {
    super.initState();
    _setupErrorHandling();
  }
  
  void _setupErrorHandling() {
    // Error handling is set up globally, but we can add local handling here
  }
  
  void _handleError(AppException error) {
    setState(() {
      _error = error;
    });
    
    widget.onError?.call(error);
    
    if (!widget.showDefaultError) {
      _errorHandler.handleError(
        error,
        null,
        context: context,
        silent: true,
      );
    }
  }
  
  void _retry() {
    setState(() {
      _error = null;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error!, _retry);
      }
      
      if (widget.showDefaultError) {
        return _DefaultErrorWidget(
          error: _error!,
          onRetry: _retry,
        );
      }
    }
    
    return _ErrorCatcher(
      onError: _handleError,
      child: widget.child,
    );
  }
}

/// Internal error catcher widget
class _ErrorCatcher extends StatelessWidget {
  final Widget child;
  final void Function(AppException error) onError;
  
  const _ErrorCatcher({
    required this.child,
    required this.onError,
  });
  
  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      final error = UnknownException(
        message: details.exception.toString(),
        originalError: details.exception,
        stackTrace: details.stack,
      );
      
      onError(error);
      
      return Container();
    };
    
    return child;
  }
}

/// Default error widget
class _DefaultErrorWidget extends StatelessWidget {
  final AppException error;
  final VoidCallback onRetry;
  
  const _DefaultErrorWidget({
    required this.error,
    required this.onRetry,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIcon(),
              size: 64,
              color: _getColor(theme),
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.userMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (error.isRetryable) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  IconData _getIcon() {
    switch (error.severity) {
      case ErrorSeverity.low:
        return Icons.info_outline;
      case ErrorSeverity.medium:
        return Icons.warning_amber;
      case ErrorSeverity.high:
        return Icons.error_outline;
      case ErrorSeverity.critical:
        return Icons.dangerous;
    }
  }
  
  Color _getColor(ThemeData theme) {
    switch (error.severity) {
      case ErrorSeverity.low:
        return theme.colorScheme.primary;
      case ErrorSeverity.medium:
        return Colors.orange;
      case ErrorSeverity.high:
        return theme.colorScheme.error;
      case ErrorSeverity.critical:
        return Colors.red.shade900;
    }
  }
}

/// Async error boundary for FutureBuilder and StreamBuilder
class AsyncErrorBoundary<T> extends StatelessWidget {
  final Future<T>? future;
  final Stream<T>? stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, AppException error)? errorBuilder;
  final T? initialData;
  
  const AsyncErrorBoundary({
    super.key,
    this.future,
    this.stream,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.initialData,
  }) : assert(future != null || stream != null, 'Either future or stream must be provided');
  
  @override
  Widget build(BuildContext context) {
    if (future != null) {
      return FutureBuilder<T>(
        future: future,
        initialData: initialData,
        builder: (context, snapshot) => _buildContent(context, snapshot),
      );
    }
    
    return StreamBuilder<T>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) => _buildContent(context, snapshot),
    );
  }
  
  Widget _buildContent(BuildContext context, AsyncSnapshot<T> snapshot) {
    if (snapshot.hasError) {
      final error = _transformError(snapshot.error!);
      
      if (errorBuilder != null) {
        return errorBuilder!(context, error);
      }
      
      return ErrorHandler().buildErrorWidget(error);
    }
    
    if (snapshot.hasData) {
      return builder(context, snapshot.data as T);
    }
    
    if (loadingBuilder != null) {
      return loadingBuilder!(context);
    }
    
    return const Center(child: CircularProgressIndicator());
  }
  
  AppException _transformError(dynamic error) {
    if (error is AppException) {
      return error;
    }
    
    return UnknownException(
      message: error.toString(),
      originalError: error,
    );
  }
}

/// Provider error boundary
class ProviderErrorBoundary extends ConsumerWidget {
  final Widget child;
  final Widget Function(AppException error, WidgetRef ref)? errorBuilder;
  
  const ProviderErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ErrorBoundary(
      errorBuilder: errorBuilder != null
        ? (error, retry) => errorBuilder!(error, ref)
        : null,
      child: child,
    );
  }
}

/// Error display widget for inline errors
class ErrorDisplay extends StatelessWidget {
  final AppException error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool compact;
  
  ErrorDisplay({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.compact = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (compact) {
      return _buildCompact(context, theme);
    }
    
    return _buildExpanded(context, theme);
  }
  
  Widget _buildCompact(BuildContext context, ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getBackgroundColor(theme),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getIcon(),
            size: 20,
            color: _getColor(theme),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error.userMessage,
              style: TextStyle(color: _getColor(theme)),
            ),
          ),
          if (onRetry != null && error.isRetryable)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRetry,
              iconSize: 20,
              color: _getColor(theme),
            ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
              iconSize: 20,
              color: _getColor(theme),
            ),
        ],
      ),
    );
  }
  
  Widget _buildExpanded(BuildContext context, ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBackgroundColor(theme),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getColor(theme).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _getIcon(),
                size: 24,
                color: _getColor(theme),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getTitle(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _getColor(theme),
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onDismiss,
                  color: _getColor(theme),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error.userMessage,
            style: theme.textTheme.bodyMedium,
          ),
          if (onRetry != null && error.isRetryable) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getColor(theme),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  String _getTitle() {
    switch (error.severity) {
      case ErrorSeverity.low:
        return 'Information';
      case ErrorSeverity.medium:
        return 'Warning';
      case ErrorSeverity.high:
        return 'Error';
      case ErrorSeverity.critical:
        return 'Critical Error';
    }
  }
  
  IconData _getIcon() {
    switch (error.severity) {
      case ErrorSeverity.low:
        return Icons.info_outline;
      case ErrorSeverity.medium:
        return Icons.warning_amber;
      case ErrorSeverity.high:
        return Icons.error_outline;
      case ErrorSeverity.critical:
        return Icons.dangerous;
    }
  }
  
  Color _getColor(ThemeData theme) {
    switch (error.severity) {
      case ErrorSeverity.low:
        return theme.colorScheme.primary;
      case ErrorSeverity.medium:
        return Colors.orange;
      case ErrorSeverity.high:
        return theme.colorScheme.error;
      case ErrorSeverity.critical:
        return Colors.red.shade900;
    }
  }
  
  Color _getBackgroundColor(ThemeData theme) {
    return _getColor(theme).withValues(alpha: 0.1);
  }
}