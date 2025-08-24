import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _logController = StreamController<String>.broadcast();
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<String> get logs => _logController.stream;
  Stream<Map<String, dynamic>> get status => _statusController.stream;
  
  void connect(String jobId) {
    final uri = Uri.parse('ws://localhost:8000/ws/jobs/$jobId');
    _channel = WebSocketChannel.connect(uri);
    
    _channel!.stream.listen(
      (data) {
        final message = jsonDecode(data);
        if (message['type'] == 'log') {
          _logController.add(message['message']);
        } else if (message['type'] == 'status') {
          _statusController.add(message['data']);
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
      onDone: () {
        print('WebSocket connection closed');
      },
    );
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