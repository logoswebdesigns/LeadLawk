import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../providers/server_status_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'dart:convert';

class ServerDiagnosticsPage extends ConsumerStatefulWidget {
  const ServerDiagnosticsPage({super.key});

  @override
  ConsumerState<ServerDiagnosticsPage> createState() => _ServerDiagnosticsPageState();
}

class _ServerDiagnosticsPageState extends ConsumerState<ServerDiagnosticsPage> {
  WebSocketChannel? _channel;
  final List<String> _live = [];

  @override
  void initState() {
    super.initState();
    _connectLogsWs(); // async helper
  }


  String sanitizeBaseUrl(String raw) {
    var s = raw;

    // Remove BOM/zero-width and control chars
    s = s.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF\u0000-\u001F\u007F]'), '');

    // Remove fragment or query (anything after # or ?)
    s = s.replaceFirst(RegExp(r'[#\?].*$'), '');

    // Trim whitespace and trailing slashes
    s = s.trim().replaceFirst(RegExp(r'/+$'), '');

    return s;
  }

  Future<void> _connectLogsWs() async {
    try {
      final rawBase = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
      final base    = sanitizeBaseUrl(rawBase);
      final u       = Uri.parse(base);

      final wsUri = u.replace(
        scheme: u.scheme == 'https' ? 'wss' : 'ws',
        // keep any base path, append /ws/logs
        path: '${u.path.isEmpty ? '' : u.path.replaceFirst(RegExp(r'/+$'), '')}/ws/logs',
        query: null,
        fragment: null,
      );

      final socket = await WebSocket.connect(wsUri.toString());
      setState(() => _channel = IOWebSocketChannel(socket));

      _channel!.stream.listen((event) {
        final line = _extractMessage(event is String ? event : event.toString());
        if (line != null) setState(() => _live.add(line));
      }, onError: (e) {
        debugPrint('WS error: $e');
      }, onDone: () {
        debugPrint('WS closed');
      });
    } catch (e) {
      debugPrint('WS connect failed (using HTTP fallback): $e');
      // Page already shows logs via HTTP fallback provider.
    }
  }


  String? _extractMessage(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final msg = map['message'];
      if (msg is String) return msg;
    } catch (_) {
      // Fallback: treat as plain line
      if (raw.isNotEmpty) return raw;
    }
    return null;
  }

  @override
  void dispose() {
    _channel?.sink.close(ws_status.normalClosure);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(serverStatusProvider);
    final notifier = ref.read(serverStatusProvider.notifier);

    Color statusColor;
    String statusText;
    switch (server.status) {
      case ServerStatus.online:
        statusColor = Colors.green;
        statusText = 'Online';
        break;
      case ServerStatus.offline:
        statusColor = Colors.red;
        statusText = 'Offline';
        break;
      case ServerStatus.starting:
        statusColor = Colors.orange;
        statusText = 'Starting';
        break;
      case ServerStatus.checking:
        statusColor = Colors.orange;
        statusText = 'Checking';
        break;
      case ServerStatus.error:
        statusColor = Colors.red;
        statusText = 'Error';
        break;
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/leads');
            }
          },
          tooltip: 'Back',
        ),
        title: const Text('Server Diagnostics', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            onPressed: () {
              notifier.checkServerHealth();
              ref.invalidate(serverLogsProvider);
            },
            tooltip: 'Recheck',
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          IconButton(
            onPressed: () async {
              try {
                final base = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
                final baseHttp = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
                final dio = ref.read(dioProvider);
                final resp = await dio.get('$baseHttp/diagnostics');
                final data = resp.data as Map<String, dynamic>;
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Environment Diagnostics'),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _diagRow('Scraper ready', data['scraper_ready'] == true),
                          _diagRow('Database OK', data['db_ok'] == true),
                          _diagRow('Log path OK', data['log_ok'] == true),
                          const SizedBox(height: 8),
                          Text('Python: ${data['python']}'),
                          Text('CWD: ${data['cwd']}'),
                          if (data['leads_count'] != null) Text('Leads in DB: ${data['leads_count']}'),
                          const SizedBox(height: 12),
                          const Text('Messages:', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          ...((data['messages'] as List<dynamic>? ?? const [])
                              .map((m) => Text('- ${m.toString()}')))
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      )
                    ],
                  ),
                );
              } catch (_) {}
            },
            tooltip: 'Diagnostics',
            icon: const Icon(Icons.science, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const Spacer(),
                if (server.lastCheck != null)
                  Expanded(
                    child: Text(
                      'Last check: ${server.lastCheck}',
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          if (server.message != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                server.message!,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          const SizedBox(height: 8),
          // Setup Instructions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Server Setup',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'To start the backend server:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        'cd server && docker-compose up -d',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This starts both the API server and browser automation containers.\nFor production deployment, use container orchestration or Docker Compose.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Server Logs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          Container(
            height: 300,
            color: Colors.black,
            child: Consumer(
              builder: (context, ref, _) {
                final logsAsync = ref.watch(serverLogsProvider);
                return logsAsync.when(
                  data: (lines) {
                    // Merge: server file logs + live WS lines + in-app captured logs
                    final merged = <String>[...lines, ..._live, ...server.logs];
                    return ListView.builder(
                      reverse: true,
                      itemCount: merged.length,
                      itemBuilder: (context, index) {
                        final line = merged[merged.length - 1 - index];
                        final isErr = line.startsWith('[ERR]') || line.contains('ERROR');
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Text(
                            line,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: isErr ? Colors.redAccent : Colors.greenAccent,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) {
                    final fallback = server.logs;
                    return ListView.builder(
                      reverse: true,
                      itemCount: fallback.length,
                      itemBuilder: (context, index) {
                        final line = fallback[fallback.length - 1 - index];
                        final isErr = line.startsWith('[ERR]') || line.contains('ERROR');
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Text(
                            line,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: isErr ? Colors.redAccent : Colors.greenAccent,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Browser Automation Jobs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          SizedBox(
            height: 220,
            child: Consumer(
              builder: (context, ref, _) {
                final jobsAsync = ref.watch(jobsListProvider);
                return jobsAsync.when(
                  data: (jobs) {
                    if (jobs.isEmpty) {
                      return const Center(child: Text('No jobs yet', style: TextStyle(color: Colors.white)));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: jobs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final j = jobs[index];
                        final status = j['status']?.toString() ?? 'unknown';
                        final jobId = j['job_id']?.toString() ?? '';
                        final processed = j['processed'] ?? 0;
                        final total = j['total'] ?? 0;
                        final color = _statusColor(status);
                        return InkWell(
                          onTap: () => _showJobLogsSheet(context, ref, jobId),
                          child: Container(
                            width: 260,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.analytics, color: color),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        jobId,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Status: $status', style: TextStyle(color: color)),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: total == 0 ? 0 : (processed / (total as num)).toDouble(),
                                  minHeight: 6,
                                  backgroundColor: color.withOpacity(0.15),
                                  valueColor: AlwaysStoppedAnimation<Color>(color),
                                ),
                                const SizedBox(height: 8),
                                Text('Processed: $processed / $total', style: const TextStyle(fontSize: 12)),
                                const Spacer(),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => _showJobLogsSheet(context, ref, jobId),
                                        child: const Text('Logs'),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => context.go('/browser/monitor/$jobId'),
                                        child: const Text('Monitor'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (_, __) => const Center(child: Text('Failed to load jobs', style: TextStyle(color: Colors.white))),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'running':
        return Colors.orange;
      case 'done':
        return Colors.green;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showJobLogsSheet(BuildContext context, WidgetRef ref, String jobId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DefaultTabController(
          length: 2,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Job $jobId', style: const TextStyle(fontWeight: FontWeight.w600))),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.go('/browser/monitor/$jobId');
                        },
                        child: const Text('Open Monitor'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.list_alt), text: 'Logs'),
                      Tab(icon: Icon(Icons.camera_alt), text: 'Screenshots'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildLogsTab(ref, jobId),
                        _buildScreenshotsTab(ref, jobId),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogsTab(WidgetRef ref, String jobId) {
    return FutureBuilder(
      future: (() {
        final base = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
        final baseHttp = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
        return ref.read(dioProvider).get(
          '$baseHttp/jobs/$jobId/logs',
          queryParameters: {'tail': 500},
        );
      })(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(child: Text('Failed to load job logs'));
        }
        final resp = snapshot.data as dynamic;
        final lines = (resp.data['lines'] as List).cast<String>();
        if (lines.isEmpty) return const Center(child: Text('No logs'));
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final text = lines.join('\n');
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Job logs copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Logs'),
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.black,
                child: ListView.builder(
                  itemCount: lines.length,
                  itemBuilder: (context, index) {
                    final line = lines[index];
                    final isErr = line.contains('ERROR') || line.contains('Traceback');
                    final isScreenshot = line.contains('📸 Screenshot captured');
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: isErr 
                              ? Colors.redAccent 
                              : isScreenshot 
                                  ? Colors.cyanAccent 
                                  : Colors.greenAccent,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScreenshotsTab(WidgetRef ref, String jobId) {
    return FutureBuilder(
      future: (() {
        final base = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
        final baseHttp = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
        return ref.read(dioProvider).get('$baseHttp/jobs/$jobId/screenshots');
      })(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(child: Text('Failed to load screenshots'));
        }
        final resp = snapshot.data as dynamic;
        final screenshots = (resp.data['screenshots'] as List).cast<Map<String, dynamic>>();
        if (screenshots.isEmpty) {
          return const Center(child: Text('No screenshots captured'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.5,
          ),
          itemCount: screenshots.length,
          itemBuilder: (context, index) {
            final screenshot = screenshots[index];
            final filename = screenshot['filename'] as String;
            final base = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
            final baseHttp = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
            final imageUrl = '$baseHttp/screenshots/$filename';
            
            // Extract description from filename
            final description = _extractScreenshotDescription(filename);
            
            return GestureDetector(
              onTap: () => _showFullScreenshot(context, screenshots, index),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                      ),
                      child: Text(
                        description,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _extractScreenshotDescription(String filename) {
    // Extract description from filename pattern: job_{jobId}_{count}_{timestamp}_{description}.png
    final parts = filename.split('_');
    if (parts.length >= 5) {
      final description = parts.sublist(4).join('_').replaceAll('.png', '');
      return description.replaceAll('_', ' ').split(' ').map((word) {
        return word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1);
      }).join(' ');
    }
    return 'Screenshot';
  }

  void _showFullScreenshot(BuildContext context, List<Map<String, dynamic>> screenshots, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => _ScreenshotGalleryDialog(
        screenshots: screenshots,
        initialIndex: initialIndex,
      ),
    );
  }
}

class _ScreenshotGalleryDialog extends StatefulWidget {
  final List<Map<String, dynamic>> screenshots;
  final int initialIndex;

  const _ScreenshotGalleryDialog({
    required this.screenshots,
    required this.initialIndex,
  });

  @override
  State<_ScreenshotGalleryDialog> createState() => _ScreenshotGalleryDialogState();
}

class _ScreenshotGalleryDialogState extends State<_ScreenshotGalleryDialog> {
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  void _previousImage() {
    setState(() {
      currentIndex = (currentIndex - 1 + widget.screenshots.length) % widget.screenshots.length;
    });
  }

  void _nextImage() {
    setState(() {
      currentIndex = (currentIndex + 1) % widget.screenshots.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentScreenshot = widget.screenshots[currentIndex];
    final filename = currentScreenshot['filename'] as String;
    final base = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
    final baseHttp = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final imageUrl = '$baseHttp/screenshots/$filename';
    final description = _extractScreenshotDescription(filename);
    
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.camera_alt),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$description (${currentIndex + 1} of ${widget.screenshots.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Failed to load screenshot'),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (widget.screenshots.length > 1) ...[
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          onPressed: _previousImage,
                          icon: const Icon(Icons.arrow_back_ios, size: 32),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          onPressed: _nextImage,
                          icon: const Icon(Icons.arrow_forward_ios, size: 32),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.screenshots.length > 1)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.screenshots.asMap().entries.map((entry) {
                    final index = entry.key;
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == currentIndex ? Colors.blue : Colors.grey,
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  String _extractScreenshotDescription(String filename) {
    // Extract description from filename pattern: job_{jobId}_{count}_{timestamp}_{description}.png
    final parts = filename.split('_');
    if (parts.length >= 5) {
      final description = parts.sublist(4).join('_').replaceAll('.png', '');
      return description.replaceAll('_', ' ').split(' ').map((word) {
        return word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1);
      }).join(' ');
    }
    return 'Screenshot';
  }
}

Widget _diagRow(String label, bool ok) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(ok ? Icons.check_circle : Icons.error, color: ok ? Colors.green : Colors.red, size: 16),
        const SizedBox(width: 6),
        Text(label),
      ],
    ),
  );
}
