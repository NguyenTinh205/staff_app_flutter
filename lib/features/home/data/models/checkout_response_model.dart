class CheckoutResponseModel {
  final String type;
  final String message;
  final String checkoutUrl;
  final String qrCode;
  final int orderCode;
  final String invoiceId;

  CheckoutResponseModel({
    required this.type,
    required this.message,
    required this.checkoutUrl,
    required this.qrCode,
    required this.orderCode,
    required this.invoiceId,
  });

  factory CheckoutResponseModel.fromJson(Map<String, dynamic> json) {
    return CheckoutResponseModel(
      type: json['type'] as String? ?? '',
      message: json['message'] as String? ?? '',
      checkoutUrl: json['checkout_url'] as String? ?? '',
      qrCode: json['qr_code'] as String? ?? '',
      orderCode: json['order_code'] as int? ?? 0,
      invoiceId: json['invoice_id']?.toString() ??
          json['invoice']?['id']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'message': message,
      'checkout_url': checkoutUrl,
      'qr_code': qrCode,
      'order_code': orderCode,
      'invoice_id': invoiceId,
    };
  }
}
