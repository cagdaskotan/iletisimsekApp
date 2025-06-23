import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  SocketService._internal();

  IO.Socket? _socket;
  Function(dynamic)? _messageCallback;

  /// Sunucuya bağlan
  void connect(String userId) {
    if (_socket == null || !_socket!.connected) {
      _socket = IO.io(
        'http://10.20.10.30:3002',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build(),
      );

      _socket?.connect();

      _socket?.onConnect((_) {
        print('🟢 Socket bağlandı');
        _socket?.emit('joinRoom', userId);
      });

      _socket?.onDisconnect((_) {
        print('🔴 Socket bağlantısı kesildi');
      });

      _socket?.on('receiveMessage', (data) {
        print('📩 Yeni mesaj geldi: $data');
        _messageCallback?.call(data); // ChatPage'e aktar
      });
    }
  }

  /// Mesaj gönder
  void sendMessage(Map<String, dynamic> message) {
    _socket?.emit('sendMessage', message); // ✅ Event adı backend ile uyumlu
    print('📤 [SOCKET SERVICE] Mesaj gönderildi: $message');
  }

  /// Gelen mesajları dinle
  void onMessageReceived(Function(dynamic) callback) {
    _messageCallback = callback;
    _socket?.off('receiveMessage'); // varsa önceki dinleyiciyi temizle
    _socket?.on('receiveMessage', callback);
  }

  /// Socket bağlantısını kes
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    print('❌ Socket bağlantısı kapatıldı');
  }

  void clearListeners() {
    _socket?.off('receiveMessage');
    _messageCallback = null;
  }
}
