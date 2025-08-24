import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../providers/server_status_provider.dart';
import 'package:go_router/go_router.dart';
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
    // Connect to WS logs; ignore failures, page will fallback to HTTP fetch
    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8000/ws/logs'));
      _channel!.stream.listen((event) {
        try {
          // Expect server to send JSON strings {type, message}
          if (event is String) {
            final line = _extractMessage(event);
            if (line != null) setState(() => _live.add(line));
          }
        } catch (_) {}
      }, onError: (_) {}, onDone: () {});
    } catch (_) {}
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/leads');
            }
          },
          tooltip: 'Back',
        ),
        title: const Text('Server Diagnostics'),
        actions: [
          IconButton(
            onPressed: () {
              notifier.checkServerHealth();
              ref.invalidate(serverLogsProvider);
            },
            tooltip: 'Recheck',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () async {
              try {
                final dio = ref.read(dioProvider);
                final resp = await dio.get('http://localhost:8000/diagnostics');
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
            icon: const Icon(Icons.science),
          ),
        ],
      ),
      body: Column(
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
                  Text(
                    'Last check: ${server.lastCheck}',
                    style: const TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
          if (server.message != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                server.message!,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Server Logs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black,
              child: Consumer(
                builder: (context, ref, _) {
                  final logsAsync = ref.watch(serverLogsProvider);
                  return logsAsync.when(
                    data: (lines) {
                      // Merge: server file logs + live WS lines + in-app captured logs
                      final merged = <String>[]
                        ..addAll(lines)
                        ..addAll(_live)
                        ..addAll(server.logs);
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
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Scrape Jobs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                      return const Center(child: Text('No jobs yet'));
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
                                    TextButton(
                                      onPressed: () => _showJobLogsSheet(context, ref, jobId),
                                      child: const Text('View Logs'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: () => context.go('/scrape/monitor/$jobId'),
                                      child: const Text('Open Monitor'),
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
                  error: (_, __) => const Center(child: Text('Failed to load jobs')),
                );
              },
            ),
          ),
        ],
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
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Job $jobId', style: const TextStyle(fontWeight: FontWeight.w600))),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.go('/scrape/monitor/$jobId');
                      },
                      child: const Text('Open Monitor'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: FutureBuilder(
                    future: ref.read(dioProvider).get('http://localhost:8000/jobs/$jobId/logs', queryParameters: {'tail': 500}),
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
                                if (!mounted) return;
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
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
