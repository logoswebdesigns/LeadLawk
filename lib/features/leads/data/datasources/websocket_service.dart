import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _logController = StreamController<String>.broadcast();
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<String> get logs => _logController.stream;
  Stream<Map<String, dynamic>> get status => _statusController.stream;

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

  Future<void> connect(String jobId) async {
    try {

      final rawBase = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
      final base    = sanitizeBaseUrl(rawBase);
      final u       = Uri.parse(base);

      final wsUri = u.replace(
        scheme: u.scheme == 'https' ? 'wss' : 'ws',
        path: '/ws/jobs/$jobId',
        query: null,
        fragment: null,
      );

      final socket = await WebSocket.connect(wsUri.toString());
      _channel = IOWebSocketChannel(socket);

      _channel!.stream.listen((data) {
        final msg = jsonDecode(data);
        if (msg['type'] == 'log') {
          _logController.add(msg['message']);
        } else if (msg['type'] == 'status') {
          _statusController.add(msg['data']);
        }
      }, onError: (e) {
        print('WebSocket error: $e');
      }, onDone: () {
        print('WebSocket connection closed');
      });
    } catch (e) {
      print('WS connect failed (using HTTP fallback): $e');
    }
  }
  
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
  
  void dispose() {
    _logController.close();
    _statusController.close();
    disconnect();
  }
}