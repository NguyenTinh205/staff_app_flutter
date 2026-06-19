import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

class SocketService {
  static socket_io.Socket? _socket;
  static const String _serverUrl =
      'https://nonoily-overinfluential-deegan.ngrok-free.dev';
  static int? _currentActiveInvoiceId;

  static socket_io.Socket? get socket => _socket;

  // Khởi tạo kết nối Socket.io
  static void connect() {
    if (_socket != null && _socket!.connected) return;

    debugPrint("DEBUG: Đang kết nối tới Socket server: $_serverUrl");
    _socket = socket_io.io(
      _serverUrl,
      socket_io.OptionBuilder()
          .setTransports([
            'websocket',
          ]) 
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint("DEBUG: Socket connected: ${_socket!.id}");
      // Rejoin room khi kết nối lại thành công
      if (_currentActiveInvoiceId != null) {
        _socket!.emit('join_invoice', _currentActiveInvoiceId);
        debugPrint(
          "DEBUG: Tự động rejoin socket room cho invoice: $_currentActiveInvoiceId",
        );
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint("DEBUG: Socket disconnected");
    });

    _socket!.onConnectError((data) {
      debugPrint("DEBUG: Socket connection error: $data");
    });
  }

  // Tham gia phòng hóa đơn (invoice)
  static void joinInvoice(int invoiceId) {
    _currentActiveInvoiceId = invoiceId;

    if (_socket == null) {
      connect();
    }

    if (_socket!.connected) {
      _socket!.emit('join_invoice', invoiceId);
      debugPrint(
        "DEBUG: Socket đã gửi lệnh join_invoice cho invoice: $invoiceId",
      );
    } else {
      // Đợi khi nào kết nối thành công thì mới gửi
      _socket!.once('connect', (_) {
        _socket!.emit('join_invoice', invoiceId);
        debugPrint(
          "DEBUG: Socket đã kết nối và gửi lệnh join_invoice cho invoice: $invoiceId",
        );
      });
      
      _socket!.connect();
    }
  }

  static void listenToPaymentComplete(Function(dynamic) onPaymentComplete) {
    if (_socket == null) return;
    
    _socket!.on('payment_complete', (data) {
      debugPrint("DEBUG [payment_complete]: Socket nhận được: $data");
      onPaymentComplete(data);
    });

    _socket!.on('PAYMENT_SUCCESS', (data) {
      debugPrint("DEBUG [PAYMENT_SUCCESS]: Socket nhận được: $data");
      onPaymentComplete(data);
    });
  }

  static void listenToPaymentFailed(Function(dynamic) onPaymentFailed) {
    if (_socket == null) return;

    _socket!.on('payment_failed', (data) {
      debugPrint("DEBUG [payment_failed]: Socket nhận được: $data");
      onPaymentFailed(data);
    });

    _socket!.on('PAYMENT_FAILED', (data) {
      debugPrint("DEBUG [PAYMENT_FAILED]: Socket nhận được: $data");
      onPaymentFailed(data);
    });
  }

  // Ngắt kết nối socket
  static void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      debugPrint("DEBUG: Đã đóng kết nối Socket");
    }
  }
}
