import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/server_status_provider.dart';

class ServerStatusIndicator extends ConsumerWidget {
  const ServerStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(serverStatusProvider);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getBackgroundColor(serverState.status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getBackgroundColor(serverState.status).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusIcon(serverState.status),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _getStatusText(serverState.status),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _getBackgroundColor(serverState.status),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (serverState.status == ServerStatus.checking ||
              serverState.status == ServerStatus.starting)
            const Padding(padding: EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(ServerStatus status) {
    switch (status) {
      case ServerStatus.online:
        return const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 16,
        );
      case ServerStatus.offline:
        return const Icon(
          Icons.cancel,
          color: Colors.red,
          size: 16,
        );
      case ServerStatus.checking:
      case ServerStatus.starting:
        return const Icon(
          Icons.sync,
          color: Colors.orange,
          size: 16,
        );
      case ServerStatus.error:
        return const Icon(
          Icons.error,
          color: Colors.red,
          size: 16,
        );
    }
  }

  Color _getBackgroundColor(ServerStatus status) {
    switch (status) {
      case ServerStatus.online:
        return Colors.green;
      case ServerStatus.offline:
      case ServerStatus.error:
        return Colors.red;
      case ServerStatus.checking:
      case ServerStatus.starting:
        return Colors.orange;
    }
  }

  String _getStatusText(ServerStatus status) {
    switch (status) {
      case ServerStatus.online:
        return 'Server Online';
      case ServerStatus.offline:
        return 'Server Offline';
      case ServerStatus.checking:
        return 'Checking...';
      case ServerStatus.starting:
        return 'Starting Server...';
      case ServerStatus.error:
        return 'Server Error';
    }
  }
}

class ServerStatusBadge extends ConsumerWidget {
  const ServerStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(serverStatusProvider);
    
    return Positioned(
      bottom: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Server Status'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Status', _getStatusText(serverState.status)),
                    if (serverState.message != null)
                      _buildInfoRow('Message', serverState.message!),
                    if (serverState.lastCheck != null)
                      _buildInfoRow(
                        'Last Check',
                        '${serverState.lastCheck!.hour.toString().padLeft(2, '0')}:'
                        '${serverState.lastCheck!.minute.toString().padLeft(2, '0')}:'
                        '${serverState.lastCheck!.second.toString().padLeft(2, '0')}',
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Server URL: http://localhost:8000',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  if (serverState.status == ServerStatus.offline)
                    TextButton(
                      onPressed: () {
                        ref.read(serverStatusProvider.notifier).checkServerHealth();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Retry'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusDot(serverState.status),
                const SizedBox(width: 8),
                Text(
                  _getShortStatusText(serverState.status),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDot(ServerStatus status) {
    Color color;
    switch (status) {
      case ServerStatus.online:
        color = Colors.green;
        break;
      case ServerStatus.offline:
      case ServerStatus.error:
        color = Colors.red;
        break;
      case ServerStatus.checking:
      case ServerStatus.starting:
        color = Colors.orange;
        break;
    }
    
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(ServerStatus status) {
    switch (status) {
      case ServerStatus.online:
        return 'Online';
      case ServerStatus.offline:
        return 'Offline';
      case ServerStatus.checking:
        return 'Checking';
      case ServerStatus.starting:
        return 'Starting';
      case ServerStatus.error:
        return 'Error';
    }
  }

  String _getShortStatusText(ServerStatus status) {
    switch (status) {
      case ServerStatus.online:
        return 'Server';
      case ServerStatus.offline:
        return 'Offline';
      case ServerStatus.checking:
        return 'Checking';
      case ServerStatus.starting:
        return 'Starting';
      case ServerStatus.error:
        return 'Error';
    }
  }
}