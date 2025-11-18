import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// TCP Socket yönetim sınıfı
/// Sunucu ile bağlantı kurar, veri gönderir/alır
class SocketManager {
  Socket? _socket;
  bool _isConnected = false;
  String? _lastHost;
  int? _lastPort;
  Timer? _reconnectTimer;
  bool _manuallyDisconnected = false;

  final _dataController = StreamController<List<int>>.broadcast();
  void Function(List<int>)? _onDataCallback;

  bool get isConnected => _isConnected;
  Stream<List<int>> get dataStream => _dataController.stream;

  /// Sunucuya bağlan
  Future<void> connect(String host, int port) async {
    if (_socket != null && _isConnected) {
      debugPrint('[SocketManager] Already connected');
      return;
    }

    _lastHost = host;
    _lastPort = port;
    _manuallyDisconnected = false;

    try {
      debugPrint('[SocketManager] Connecting to $host:$port...');
      _socket = await Socket.connect(host, port);
      _isConnected = true;
      debugPrint('[SocketManager] ✅ Connected to $host:$port');

      // Veri dinleyici
      _socket!.listen(
        (data) {
          debugPrint('[SocketManager] 📥 RX: ${data.length} bytes');
          _dataController.add(data);
          _onDataCallback?.call(data);
        },
        onError: (error) {
          debugPrint('[SocketManager] ❌ Error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[SocketManager] 🔌 Disconnected by server');
          _handleDisconnect();
        },
      );

      // Bağlantı stabilize olsun diye kısa bekleme
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('[SocketManager] ⏳ Ready to send data');
    } catch (e) {
      debugPrint('[SocketManager] ❌ Connection failed: $e');
      _handleDisconnect();
      rethrow;
    }
  }

  /// Bağlantı koptuğunda
  void _handleDisconnect() {
    _socket?.destroy();
    _socket = null;
    _isConnected = false;

    // Otomatik yeniden bağlantı
    if (!_manuallyDisconnected && _reconnectTimer == null) {
      debugPrint('[SocketManager] 🔄 Will retry in 10 seconds...');
      _reconnectTimer = Timer.periodic(const Duration(seconds: 10), (
        timer,
      ) async {
        if (_lastHost != null && _lastPort != null) {
          _socket?.destroy();
          _socket = null;
          debugPrint('[SocketManager] 🔄 Reconnecting...');
          try {
            await connect(_lastHost!, _lastPort!);
            if (_isConnected) {
              timer.cancel();
              _reconnectTimer = null;
            }
          } catch (e) {
            debugPrint('[SocketManager] Reconnect failed: $e');
          }
        }
      });
    }
  }

  /// Bağlantı kurulana kadar bekle
  Future<void> waitUntilConnected({int maxRetries = 25}) async {
    const retryDelay = Duration(milliseconds: 200);
    int retries = 0;

    while (!_isConnected && retries < maxRetries) {
      await Future.delayed(retryDelay);
      retries++;
    }

    if (!_isConnected) {
      throw Exception('Connection timeout after ${maxRetries * 200}ms');
    }
  }

  /// Veri gönder
  Future<void> send(List<int> data) async {
    if (!_isConnected) {
      debugPrint('[SocketManager] ⚠️ Not connected. Waiting...');
      await waitUntilConnected();
    }
    
    try {
      _socket!.add(data);
      // NOT: flush() çağırmıyoruz (old_update'deki gibi)
      debugPrint('[SocketManager] 📤 TX: ${data.length} bytes');
    } catch (e) {
      debugPrint('[SocketManager] ❌ Send error: $e');
      rethrow;
    }
  }

  /// Veri gönder ve cevap bekle
  Future<List<int>> sendAndWaitResponse(
    List<int> data, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = Completer<List<int>>();
    late StreamSubscription sub;

    // Gelen veriyi dinle
    sub = _dataController.stream.listen((receivedData) {
      if (!completer.isCompleted) {
        completer.complete(receivedData);
        sub.cancel();
      }
    });

    // Veriyi gönder
    await send(data);

    // Timeout ile bekle
    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          sub.cancel();
          debugPrint('[SocketManager] ⏱️ Timeout waiting for response');
          return <int>[];
        },
      );
    } catch (e) {
      sub.cancel();
      rethrow;
    }
  }

  /// Veri dinleme callback'i ayarla
  void setOnData(void Function(List<int>) callback) {
    _onDataCallback = callback;
  }

  /// Bağlantıyı kapat
  void disconnect() {
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socket?.destroy();
    _socket = null;
    _isConnected = false;
    debugPrint('[SocketManager] 🔌 Disconnected manually');
  }

  /// Kaynakları temizle
  Future<void> dispose() async {
    disconnect();
    await _dataController.close();
  }
}
