class InvoiceModel {
  final int id;
  final String invoiceCode;
  final int employeeId;
  final int branchId;
  final int? memberId;
  final String tableNumber;
  final int subTotal;
  final int discountAmount;
  final int voucherDiscount;
  final int finalAmount;
  final int pointsEarned;
  final int pointsMultiplier;
  final String status;
  final int taxAmount;
  final int serviceCharge;
  final String createdAt;
  final String updatedAt;
  final List<InvoiceItemModel> items;

  InvoiceModel({
    required this.id,
    required this.invoiceCode,
    required this.employeeId,
    required this.branchId,
    this.memberId,
    required this.tableNumber,
    required this.subTotal,
    required this.discountAmount,
    required this.voucherDiscount,
    required this.finalAmount,
    required this.pointsEarned,
    required this.pointsMultiplier,
    required this.status,
    required this.taxAmount,
    required this.serviceCharge,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List? ?? [];
    List<InvoiceItemModel> parsedItems =
        itemsList.map((i) => InvoiceItemModel.fromJson(i)).toList();

    int parseToInt(dynamic val, int defaultVal) {
      if (val == null) return defaultVal;
      if (val is num) return val.toInt();
      if (val is String) {
        return int.tryParse(val) ?? defaultVal;
      }
      return defaultVal;
    }

    final parsedId = parseToInt(json['id'], 0);
    if (parsedId == 0) {
      throw const FormatException('ID hóa đơn không hợp lệ hoặc bằng 0 từ máy chủ');
    }

    return InvoiceModel(
      id: parsedId,
      invoiceCode: json['invoice_code']?.toString() ?? '',
      employeeId: parseToInt(json['employee_id'], 0),
      branchId: parseToInt(json['branch_id'], 0),
      memberId: json['member_id'] != null ? parseToInt(json['member_id'], 0) : null,
      tableNumber: json['table_number']?.toString() ?? '',
      subTotal: parseToInt(json['sub_total'], 0),
      discountAmount: parseToInt(json['discount_amount'], 0),
      voucherDiscount: parseToInt(json['voucher_discount'], 0),
      finalAmount: parseToInt(json['final_amount'], 0),
      pointsEarned: parseToInt(json['points_earned'], 0),
      pointsMultiplier: parseToInt(json['points_multiplier'], 1),
      status: json['status']?.toString() ?? '',
      taxAmount: parseToInt(json['tax_amount'], 0),
      serviceCharge: parseToInt(json['service_charge'], 0),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_code': invoiceCode,
      'employee_id': employeeId,
      'branch_id': branchId,
      'member_id': memberId,
      'table_number': tableNumber,
      'sub_total': subTotal,
      'discount_amount': discountAmount,
      'voucher_discount': voucherDiscount,
      'final_amount': finalAmount,
      'points_earned': pointsEarned,
      'points_multiplier': pointsMultiplier,
      'status': status,
      'tax_amount': taxAmount,
      'service_charge': serviceCharge,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}

class InvoiceItemModel {
  final int id;
  final int invoiceId;
  final int productId;
  final String productName;
  final int quantity;
  final int unitPrice;

  InvoiceItemModel({
    required this.id,
    required this.invoiceId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    int parseToInt(dynamic val, int defaultVal) {
      if (val == null) return defaultVal;
      if (val is num) return val.toInt();
      if (val is String) {
        return int.tryParse(val) ?? defaultVal;
      }
      return defaultVal;
    }

    return InvoiceItemModel(
      id: parseToInt(json['id'], 0),
      invoiceId: parseToInt(json['invoice_id'], 0),
      productId: parseToInt(json['product_id'], 0),
      productName: json['product_name']?.toString() ?? '',
      quantity: parseToInt(json['quantity'], 0),
      unitPrice: parseToInt(json['unit_price'], 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }
}
