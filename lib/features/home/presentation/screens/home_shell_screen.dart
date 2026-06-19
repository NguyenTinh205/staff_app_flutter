import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:staffapp/core/widgets/dot_grid_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staffapp/features/auth/presentation/screens/staff_login_screen.dart';
import 'package:staffapp/features/home/presentation/screens/order_product_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:staffapp/core/di/injection.dart';
import 'package:staffapp/features/home/presentation/controllers/product_controller.dart';
import 'package:staffapp/features/home/data/models/payment_method_model.dart';
import 'package:staffapp/features/home/data/models/product_model.dart';
import 'package:staffapp/features/home/data/models/invoice_model.dart';
import 'package:staffapp/core/services/socket_service.dart';
import 'package:staffapp/features/auth/presentation/controllers/login_controller.dart';
import 'package:staffapp/core/widgets/custom_notification.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _selectedTab = 0; // 0: Sơ đồ bàn, 1: Lịch sử hóa đơn
  String _selectedArea = 'Tầng 1';
  String _selectedInvoiceFilter = 'all'; // all, paid, draft

  // Dữ liệu giả lập cho Sơ đồ bàn
  final List<Map<String, dynamic>> _tables = List.generate(16, (index) {
    final number = index + 1;
    return {
      'id': 'table_$number',
      'name': 'Bàn A$number',
      'status': 'empty', // Mặc định tất cả bàn đều là bàn trống
      'adults': 0,
      'children': 0,
      'guests': 0,
      'timeStarted': null,
      'orders': <Map<String, dynamic>>[],
      'invoice_id': null,
      'invoice_code': null,
    };
  });

  // Dữ liệu cho Lịch sử hóa đơn
  final List<Map<String, dynamic>> _invoices = [
    {
      'id': 'HD-000169',
      'table': 'Bàn A5',
      'time': '10:47 - 17/06/2026',
      'amount': 430000,
      'guests': 2,
      'status': 'paid',
      'paymentMethod': 'PayOS',
      'tax': 4300,
      'serviceCharge': 2000,
      'pointsEarned': 43,
      'member': {'name': 'Nguyễn Văn A', 'phone': '0987654321'},
      'items': [
        {'name': 'Vé Buffet Người Lớn', 'price': 189000, 'quantity': 2},
        {'name': 'Coca Cola', 'price': 15000, 'quantity': 2},
        {'name': 'Phụ thu cuối tuần', 'price': 50000, 'quantity': 2},
      ],
    },
    {
      'id': 'HD-000168',
      'table': 'Bàn A12',
      'time': '09:30 - 17/06/2026',
      'amount': 968000,
      'guests': 4,
      'status': 'paid',
      'paymentMethod': 'Tiền mặt',
      'tax': 9680,
      'serviceCharge': 2000,
      'pointsEarned': 96,
      'member': null,
      'items': [
        {'name': 'Vé Buffet Người Lớn', 'price': 189000, 'quantity': 4},
        {'name': 'Bia Heineken', 'price': 25000, 'quantity': 4},
        {'name': 'Phụ thu ngày lễ', 'price': 80000, 'quantity': 4},
      ],
    },
    {
      'id': 'HD-000167',
      'table': 'Bàn A3',
      'time': '20:15 - 16/06/2026',
      'amount': 221000,
      'guests': 1,
      'status': 'paid',
      'paymentMethod': 'PayOS',
      'tax': 2210,
      'serviceCharge': 2000,
      'pointsEarned': 0,
      'member': null,
      'items': [
        {'name': 'Vé Buffet Người Lớn', 'price': 189000, 'quantity': 1},
        {'name': 'Khăn lạnh', 'price': 5000, 'quantity': 2},
        {'name': 'Nước suối', 'price': 10000, 'quantity': 1},
        {'name': 'Phụ thu cuối tuần', 'price': 50000, 'quantity': 1},
      ],
    },
    {
      'id': 'HD-000166',
      'table': 'Bàn A1',
      'time': '18:45 - 16/06/2026',
      'amount': 393000,
      'guests': 2,
      'status': 'draft',
      'paymentMethod': 'PayOS',
      'tax': 3930,
      'serviceCharge': 2000,
      'pointsEarned': 0,
      'member': null,
      'items': [
        {'name': 'Vé Buffet Người Lớn', 'price': 189000, 'quantity': 2},
        {'name': 'Coca Cola', 'price': 15000, 'quantity': 1},
      ],
    },
  ];

  late final ProductController _productController;
  String? _activeDialogTable;

  Future<void> _saveTablesState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> serializableTables = _tables.map((
        table,
      ) {
        final Map<String, dynamic> copy = Map.from(table);
        if (copy['timeStarted'] != null && copy['timeStarted'] is DateTime) {
          copy['timeStarted'] = (copy['timeStarted'] as DateTime)
              .toIso8601String();
        }
        return copy;
      }).toList();
      final String jsonStr = jsonEncode(serializableTables);
      await prefs.setString('tables_state_key', jsonStr);

      final List<String> paidTablesList = _productController.paidTables
          .toList();
      await prefs.setStringList('paid_tables_key', paidTablesList);

      debugPrint(
        "DEBUG LOCAL STORAGE: Đã lưu trạng thái các bàn và bàn đã thanh toán.",
      );
    } catch (e) {
      debugPrint("DEBUG LOCAL STORAGE ERROR: Không thể lưu trạng thái: $e");
    }
  }

  Future<void> _loadTablesState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('tables_state_key');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(jsonStr);
        setState(() {
          for (int i = 0; i < decodedList.length; i++) {
            if (i < _tables.length) {
              final Map<String, dynamic> loadedTable =
                  Map<String, dynamic>.from(decodedList[i]);

              if (loadedTable['timeStarted'] != null) {
                loadedTable['timeStarted'] = DateTime.tryParse(
                  loadedTable['timeStarted'].toString(),
                );
              }

              if (loadedTable['orders'] != null) {
                loadedTable['orders'] = List<Map<String, dynamic>>.from(
                  (loadedTable['orders'] as List).map(
                    (item) => Map<String, dynamic>.from(item),
                  ),
                );
              } else {
                loadedTable['orders'] = <Map<String, dynamic>>[];
              }

              _tables[i]['status'] = loadedTable['status'];
              _tables[i]['adults'] = loadedTable['adults'];
              _tables[i]['children'] = loadedTable['children'];
              _tables[i]['guests'] = loadedTable['guests'];
              _tables[i]['timeStarted'] = loadedTable['timeStarted'];
              _tables[i]['orders'] = loadedTable['orders'];
              _tables[i]['invoice_id'] = loadedTable['invoice_id'];
              _tables[i]['invoice_code'] = loadedTable['invoice_code'];

              if (_tables[i]['status'] == 'serving' &&
                  _tables[i]['invoice_id'] != null) {
                final invId = int.tryParse(_tables[i]['invoice_id'].toString());
                if (invId != null) {
                  SocketService.joinInvoice(invId);
                }
              }
            }
          }
        });
      }

      final List<String>? paidTablesList = prefs.getStringList(
        'paid_tables_key',
      );
      if (paidTablesList != null) {
        for (var tableName in paidTablesList) {
          _productController.markTableAsPaid(tableName);
        }
      }

      debugPrint("DEBUG LOCAL STORAGE: Đã phục hồi trạng thái các bàn.");
    } catch (e) {
      debugPrint(
        "DEBUG LOCAL STORAGE ERROR: Không thể phục hồi trạng thái: $e",
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _productController = sl<ProductController>();
    _loadTablesState(); // Tải trạng thái lưu trữ cục bộ
    _productController
        .fetchCategoriesAndProducts(); // Tải danh sách món ăn từ API lên Controller
    SocketService.connect(); // Khởi động kết nối socket
    SocketService.listenToPaymentComplete((data) {
      debugPrint("=========================================");
      debugPrint("DEBUG TRÊN UI [PAYMENT SUCCESS EVENT DETECTED]");
      debugPrint("Dữ liệu nhận được từ Socket: $data");
      debugPrint("=========================================");

      if (data == null) return;

      // Giả sử data có cấu trúc chứa thông tin bàn hoặc mã hóa đơn
      String? tableNumber =
          data['table_number']?.toString() ??
          data['tableNumber']?.toString() ??
          data['invoice']?['table_number']?.toString() ??
          data['invoice']?['tableNumber']?.toString();

      // Fallback: Nếu không có table_number trong payload, tự động tìm bàn dựa vào invoice_id hoặc invoice_code
      if (tableNumber == null) {
        final targetInvoiceId =
            data['invoice_id'] ?? data['invoice']?['id'] ?? data['id'];
        final targetInvoiceCode =
            data['invoice_code']?.toString() ??
            data['invoice']?['invoice_code']?.toString();

        if (targetInvoiceId != null || targetInvoiceCode != null) {
          try {
            final foundTable = _tables.firstWhere(
              (t) =>
                  (targetInvoiceId != null &&
                      t['invoice_id']?.toString() ==
                          targetInvoiceId.toString()) ||
                  (targetInvoiceCode != null &&
                      t['invoice_code']?.toString().trim().toLowerCase() ==
                          targetInvoiceCode.toString().trim().toLowerCase()),
            );
            tableNumber = foundTable['name']?.toString();
            debugPrint(
              "DEBUG TRÊN UI: Tìm thấy bàn tương ứng từ invoice: $tableNumber",
            );
          } catch (e) {
            debugPrint(
              "DEBUG TRÊN UI: Không tìm thấy bàn nào có invoice_id: $targetInvoiceId hoặc invoice_code: $targetInvoiceCode",
            );
          }
        }
      }

      if (tableNumber != null) {
        InvoiceModel? completedInvoice;
        try {
          final invoiceData = data['invoice'] ?? data;
          if (invoiceData is Map<String, dynamic>) {
            completedInvoice = InvoiceModel.fromJson(invoiceData);
          }
        } catch (e) {
          debugPrint("DEBUG PARSE INVOICE FROM SOCKET ERROR: $e");
        }

        // Đánh dấu bàn đã thanh toán thành công trong controller và lưu hóa đơn chốt
        _productController.markTableAsPaid(tableNumber, completedInvoice);
        _saveTablesState();

        final int? points =
            completedInvoice?.pointsEarned ??
            data['points_earned'] as int? ??
            data['pointsEarned'] as int? ??
            data['invoice']?['points_earned'] as int? ??
            int.tryParse(data['points_earned']?.toString() ?? '') ??
            int.tryParse(data['invoice']?['points_earned']?.toString() ?? '');

        String snackMsg =
            'Hệ thống: Khách hàng tại $tableNumber đã chuyển khoản thành công!';
        if (points != null && points > 0) {
          snackMsg += ' Thành viên được tích lũy thêm +$points điểm!';
        }
        snackMsg += ' Nhân viên có thể hoàn tất hóa đơn và đóng bàn.';

        CustomNotification.show(
          context,
          message: snackMsg,
          backgroundColor: Colors.green,
          icon: Icons.check_circle_outline,
        );
      }
    });

    // Lắng nghe sự kiện thanh toán thất bại từ socket server
    SocketService.listenToPaymentFailed((data) {
      debugPrint("=========================================");
      debugPrint("DEBUG TRÊN UI [PAYMENT FAILED EVENT DETECTED]");
      debugPrint("Dữ liệu nhận được từ Socket: $data");
      debugPrint("=========================================");

      if (data == null) return;

      String? tableNumber =
          data['table_number']?.toString() ??
          data['tableNumber']?.toString() ??
          data['invoice']?['table_number']?.toString() ??
          data['invoice']?['tableNumber']?.toString();

      // Fallback: Tìm bàn dựa vào invoice_id hoặc invoice_code
      if (tableNumber == null) {
        final targetInvoiceId = data['invoice_id'];
        final targetInvoiceCode = data['invoice_code']?.toString();

        if (targetInvoiceId != null || targetInvoiceCode != null) {
          try {
            final foundTable = _tables.firstWhere(
              (t) =>
                  (targetInvoiceId != null &&
                      t['invoice_id']?.toString() ==
                          targetInvoiceId.toString()) ||
                  (targetInvoiceCode != null &&
                      t['invoice_code']?.toString().trim().toLowerCase() ==
                          targetInvoiceCode.toString().trim().toLowerCase()),
            );
            tableNumber = foundTable['name']?.toString();
            debugPrint(
              "DEBUG TRÊN UI: Tìm thấy bàn tương ứng từ invoice: $tableNumber",
            );
          } catch (e) {
            debugPrint(
              "DEBUG TRÊN UI: Không tìm thấy bàn nào có invoice_id: $targetInvoiceId hoặc invoice_code: $targetInvoiceCode",
            );
          }
        }
      }

      if (tableNumber != null) {
        CustomNotification.show(
          context,
          message:
              'Hệ thống: Khách hàng tại $tableNumber thanh toán thất bại hoặc đã hủy giao dịch!',
          backgroundColor: Colors.red,
          icon: Icons.error_outline,
        );
      }
    });
  }

  @override
  void dispose() {
    SocketService.disconnect(); // Đóng kết nối khi huỷ màn hình
    super.dispose();
  }

  void _openTable(int index) {
    final table = _tables[index];
    int adultCount = 2;
    int childCount = 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161615),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: const Color(0xFFFED876).withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFED876).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Color(0xFFFED876),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Mở ${table['name']}',
                    style: const TextStyle(
                      color: Color(0xFFFED876),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1D),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFED876).withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF7A704A),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Người lớn:',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (adultCount > 1) {
                                      setDialogState(() => adultCount--);
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    color: Color(0xFFFED876),
                                    size: 26,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '$adultCount',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setDialogState(() => adultCount++);
                                  },
                                  icon: const Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: Color(0xFFFED876),
                                    size: 26,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: Color(0xFF2E2E2D), height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.child_care_rounded,
                                  color: Color(0xFF7A704A),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Trẻ em:',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (childCount > 0) {
                                      setDialogState(() => childCount--);
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    color: Color(0xFFFED876),
                                    size: 26,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '$childCount',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setDialogState(() => childCount++);
                                  },
                                  icon: const Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: Color(0xFFFED876),
                                    size: 26,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(
                      color: Color(0xFF7A704A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFED876),
                    foregroundColor: const Color(0xFF1E1E1E),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFED876),
                        ),
                      ),
                    );

                    // Tìm sản phẩm Buffet từ API để lấy tên và giá thực tế
                    final prodAdult = _productController.products.firstWhere(
                      (p) {
                        final nameLower = p.name.toLowerCase();
                        return nameLower.contains('buffet') &&
                            (nameLower.contains('người lớn') ||
                                nameLower.contains('nguoi lon'));
                      },
                      orElse: () => ProductModel(
                        id: '0',
                        name: 'Vé Buffet Người Lớn',
                        price: 0,
                        categoryId: '',
                        isAvailable: true,
                      ),
                    );
                    final prodChild = _productController.products.firstWhere(
                      (p) {
                        final nameLower = p.name.toLowerCase();
                        return nameLower.contains('buffet') &&
                            (nameLower.contains('trẻ em') ||
                                nameLower.contains('tre em'));
                      },
                      orElse: () => ProductModel(
                        id: '0',
                        name: 'Vé Buffet Trẻ Em (6-11 tuổi)',
                        price: 0,
                        categoryId: '',
                        isAvailable: true,
                      ),
                    );

                    final List<Map<String, dynamic>> initialItems = [];
                    if (adultCount > 0) {
                      initialItems.add({
                        'product_id': int.tryParse(prodAdult.id) ?? 1,
                        'product_name': prodAdult.name,
                        'quantity': adultCount,
                        'unit_price': prodAdult.price,
                      });
                    }
                    if (childCount > 0) {
                      initialItems.add({
                        'product_id': int.tryParse(prodChild.id) ?? 2,
                        'product_name': prodChild.name,
                        'quantity': childCount,
                        'unit_price': prodChild.price,
                      });
                    }

                    // Tính tổng tiền tạm tính khi mở bàn để tính 1% thuế
                    int initialTotal =
                        (adultCount * prodAdult.price) +
                        (childCount * prodChild.price);
                    int surchargeVal = 0;
                    final now = DateTime.now();
                    final holidays = ['01-01', '30-04', '01-05', '02-09'];
                    final currentDayMonth =
                        "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}";
                    if (holidays.contains(currentDayMonth)) {
                      surchargeVal = (adultCount + childCount) * 80000;
                    } else if (now.weekday == DateTime.saturday ||
                        now.weekday == DateTime.sunday) {
                      surchargeVal = (adultCount + childCount) * 50000;
                    }
                    int initialBaseTotal = initialTotal + surchargeVal;
                    int calculatedTax = (initialBaseTotal * 0.10).round();
                    int calculatedService = 0;

                    // Gọi API thực tế thông qua ProductController
                    final invoice = await _productController.createDraftInvoice(
                      memberId: null, // Ban đầu chưa chọn thành viên
                      tableNumber: table['name'],
                      taxAmount: calculatedTax,
                      serviceCharge: calculatedService,
                      pointsMultiplier: 1,
                      items: initialItems,
                    );

                    if (context.mounted) {
                      Navigator.pop(context); // Đóng vòng tải loading
                    }

                    if (invoice == null) {
                      if (context.mounted) {
                        CustomNotification.show(
                          context,
                          message:
                              _productController.errorMessage ??
                              'Không thể mở bàn trên Server',
                          backgroundColor: Colors.redAccent,
                          icon: Icons.error_outline,
                        );
                      }
                      return; // Không đóng dialog mở bàn nếu lỗi
                    }

                    // Lưu trạng thái và thông tin hóa đơn thật vào state của bàn
                    setState(() {
                      _tables[index]['status'] = 'serving';
                      _tables[index]['adults'] = adultCount;
                      _tables[index]['children'] = childCount;
                      _tables[index]['guests'] = adultCount + childCount;
                      _tables[index]['timeStarted'] = DateTime.now();
                      _tables[index]['orders'] = <Map<String, dynamic>>[];
                      _tables[index]['invoice_id'] = invoice.id;
                      _tables[index]['invoice_code'] = invoice.invoiceCode;
                    });
                    _saveTablesState();

                    // Kết nối Socket.io và tham gia phòng của hóa đơn vừa tạo
                    SocketService.joinInvoice(invoice.id);

                    if (context.mounted) {
                      Navigator.pop(context); // Đóng Dialog Mở bàn
                      CustomNotification.show(
                        context,
                        message:
                            'Đã mở thành công ${table['name']} (Mã HĐ: ${invoice.invoiceCode})',
                        backgroundColor: const Color(0xFF6B5805),
                        icon: Icons.check_circle_outline,
                      );
                    }
                  },
                  child: const Text('Mở bàn'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Map<String, dynamic> _calculateInvoiceDetails(
    int adults,
    int children,
    List<Map<String, dynamic>> orders,
  ) {
    // Tìm sản phẩm Buffet Người Lớn từ danh sách API
    final prodAdult = _productController.products.firstWhere(
      (p) {
        final nameLower = p.name.toLowerCase();
        return nameLower.contains('buffet') &&
            (nameLower.contains('người lớn') ||
                nameLower.contains('nguoi lon'));
      },
      orElse: () => ProductModel(
        id: '0',
        name: 'Vé Buffet Người Lớn',
        price: 0,
        categoryId: '',
        isAvailable: true,
      ),
    );
    final int priceAdult = prodAdult.price;

    // Tìm sản phẩm Buffet Trẻ Em từ danh sách API
    final prodChild = _productController.products.firstWhere(
      (p) {
        final nameLower = p.name.toLowerCase();
        return nameLower.contains('buffet') &&
            (nameLower.contains('trẻ em') || nameLower.contains('tre em'));
      },
      orElse: () => ProductModel(
        id: '0',
        name: 'Vé Buffet Trẻ Em (6-11 tuổi)',
        price: 0,
        categoryId: '',
        isAvailable: true,
      ),
    );
    final int priceChild = prodChild.price;

    final now = DateTime.now();
    int surchargePerGuest = 0;
    String surchargeType = '';

    // Danh sách ngày lễ cố định
    final holidays = ['01-01', '30-04', '01-05', '02-09'];
    final currentDayMonth =
        "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}";

    if (holidays.contains(currentDayMonth)) {
      surchargePerGuest = 80000;
      surchargeType = 'Phụ thu ngày lễ';
    } else if (now.weekday == DateTime.saturday ||
        now.weekday == DateTime.sunday) {
      surchargePerGuest = 50000;
      surchargeType = 'Phụ thu cuối tuần';
    }

    final totalGuests = adults + children;
    final costAdult = adults * priceAdult;
    final costChild = children * priceChild;
    final costSurcharge = totalGuests * surchargePerGuest;

    // Tính tiền món gọi thêm
    final costOrders = orders.fold<int>(
      0,
      (sum, item) => sum + ((item['price'] as int) * (item['quantity'] as int)),
    );

    final totalCost = costAdult + costChild + costSurcharge + costOrders;

    return {
      'costAdult': costAdult,
      'costChild': costChild,
      'costSurcharge': costSurcharge,
      'surchargeType': surchargeType,
      'surchargePerGuest': surchargePerGuest,
      'costOrders': costOrders,
      'totalCost': totalCost,
    };
  }

  void _viewTableDetail(int index) {
    final table = _tables[index];
    final int adults = table['adults'] ?? 0;
    final int children = table['children'] ?? 0;
    final orders = List<Map<String, dynamic>>.from(table['orders'] ?? []);
    final invoiceDetails = _calculateInvoiceDetails(adults, children, orders);
    final int baseCost = invoiceDetails['totalCost'] as int;
    final int calculatedTax = (baseCost * 0.10).round();
    final int calculatedService = 0;
    final int estimatedTotal = baseCost + calculatedTax + calculatedService;
    final timeStarted = table['timeStarted'] as DateTime?;

    String elapsedTimeStr = '0 phút';
    if (timeStarted != null) {
      final diff = DateTime.now().difference(timeStarted);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      if (hours > 0) {
        elapsedTimeStr = '$hours giờ $minutes phút';
      } else {
        elapsedTimeStr = '$minutes phút';
      }
    }

    String timeStartedStr = '';
    if (timeStarted != null) {
      timeStartedStr =
          "${timeStarted.hour.toString().padLeft(2, '0')}:${timeStarted.minute.toString().padLeft(2, '0')}";
    }

    _activeDialogTable = table['name'];
    showDialog(
      context: context,
      builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161615),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: const Color(0xFFFED876).withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFED876).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.table_restaurant_rounded,
                          color: Color(0xFFFED876),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        table['name'],
                        style: const TextStyle(
                          color: Color(0xFFFED876),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B5805).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFED876).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'ĐANG PHỤC VỤ',
                      style: TextStyle(
                        color: Color(0xFFFED876),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              content: Container(
                width: 480,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // Card thông tin chung
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1D),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFED876).withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow('Người lớn', '$adults người'),
                            if (children > 0) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(color: Color(0xFF2E2E2D), height: 1),
                              ),
                              _buildDetailRow('Trẻ em', '$children người'),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(color: Color(0xFF2E2E2D), height: 1),
                            ),
                            _buildDetailRow('Tổng số khách', '${table['guests']} người'),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(color: Color(0xFF2E2E2D), height: 1),
                            ),
                            _buildDetailRow('Giờ bắt đầu', timeStartedStr),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(color: Color(0xFF2E2E2D), height: 1),
                            ),
                            _buildDetailRow('Thời gian đã ngồi', elapsedTimeStr),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Món gọi thêm
                      if (orders.isNotEmpty) ...[
                        const Text(
                          'Món gọi thêm:',
                          style: TextStyle(
                            color: Color(0xFFFED876),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1D),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFED876).withValues(alpha: 0.05),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: const [
                                  SizedBox(width: 25, child: Text('STT', style: TextStyle(color: Color(0xFF7A704A), fontSize: 11, fontWeight: FontWeight.bold))),
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      'Tên món',
                                      style: TextStyle(
                                        color: Color(0xFF7A704A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 30,
                                    child: Text(
                                      'SL',
                                      style: TextStyle(
                                        color: Color(0xFF7A704A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'T.Tiền',
                                      style: TextStyle(
                                        color: Color(0xFF7A704A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(color: Color(0xFF2E2E2D), height: 1),
                              ),
                              ...List.generate(orders.length, (idx) {
                                final item = orders[idx];
                                final int price = item['price'] as int;
                                final int qty = item['quantity'] as int;
                                final int itemTotal = price * qty;
                                final totalStr = itemTotal.toString().replaceAllMapped(
                                  RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"),
                                  (Match m) => "${m[1]}.",
                                );

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: Text(
                                          item['name'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '$qty',
                                          style: const TextStyle(
                                            color: Color(0xFFFED876),
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          '$totalStr đ',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Chi phí chi tiết
                      const Text(
                        'Chi tiết chi phí:',
                        style: TextStyle(
                          color: Color(0xFFFED876),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1D),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFED876).withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              'Tạm tính',
                              '${(invoiceDetails['totalCost'] - invoiceDetails['costSurcharge']).toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                            ),
                            if (invoiceDetails['costSurcharge'] > 0) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Divider(color: Color(0xFF2E2E2D), height: 1),
                              ),
                              _buildDetailRow(
                                invoiceDetails['surchargeType'],
                                '${(invoiceDetails['costSurcharge'] as int).toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                              ),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Divider(color: Color(0xFF2E2E2D), height: 1),
                            ),
                            _buildDetailRow(
                              'Phí dịch vụ',
                              '${calculatedService.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Divider(color: Color(0xFF2E2E2D), height: 1),
                            ),
                            _buildDetailRow(
                              'Thuế (VAT)',
                              '${calculatedTax.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(color: Color(0xFF2E2E2D), height: 1),
                            ),
                            _buildDetailRow(
                              'Ước lượng hóa đơn',
                              '${estimatedTotal.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                              valueColor: const Color(0xFFFED876),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(color: Color(0xFF7A704A), fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFED876).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFFFED876),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFFED876), width: 1),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    Navigator.pop(context); // Đóng Dialog chi tiết
                    final result = await Navigator.push<List<Map<String, dynamic>>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderProductScreen(
                          tableName: table['name'],
                          initialOrders: orders,
                        ),
                      ),
                    );
                    if (result != null) {
                      print("DEBUG MÀN HÌNH CHÍNH (NHẬN MÓN ĐÃ GỌI): $result");
                      setState(() {
                        _tables[index]['orders'] = result;
                      });
                      _saveTablesState();
                      // Hiển thị lại chi tiết với cập nhật mới
                      _viewTableDetail(index);
                    }
                  },
                  child: const Text('Gọi món / Thêm món', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFED876),
                    foregroundColor: const Color(0xFF1E1E1E),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Đóng Dialog chi tiết
                    _showPaymentConfirmationDialog(
                      context,
                      index,
                    ); // Mở Dialog xác nhận thanh toán
                  },
                  child: const Text(
                    'Thanh toán',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
      },
    ).then((_) {
      if (_activeDialogTable == table['name']) {
        _activeDialogTable = null;
      }
    });
  }

  void _showPaymentConfirmationDialog(BuildContext context, int index) {
    final table = _tables[index];
    final int adults = table['adults'] ?? 0;
    final int children = table['children'] ?? 0;
    final orders = List<Map<String, dynamic>>.from(table['orders'] ?? []);
    final invoiceDetails = _calculateInvoiceDetails(adults, children, orders);

    void Function()? dialogListener;

    _activeDialogTable = table['name'];
    final voucherController = TextEditingController();
    final phoneController = TextEditingController();
    bool isLoaded = false;
    bool isListenerRegistered = false;
    String? selectedMethodCode;
    String selectedMethodName = 'Tiền mặt';
    String? appliedVoucher;
    int discountAmount = 0;
    String? voucherError;
    Map<String, dynamic>? memberInfo;
    String? memberError;
    bool showQrCode = false;
    final List<Map<String, dynamic>> apiItems = [];
    InvoiceModel? serverInvoice;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final int baseTotal = invoiceDetails['totalCost'] as int;
            final int grandTotal = (baseTotal - discountAmount) < 0
                ? 0
                : (baseTotal - discountAmount);
            final int pointsEarned = (grandTotal * 0.01).round();

            if (!isLoaded) {
              isLoaded = true;
              _productController.clearCheckoutData();

              // Tìm sản phẩm Buffet từ API để lấy tên và giá thực tế
              final prodAdult = _productController.products.firstWhere(
                (p) {
                  final nameLower = p.name.toLowerCase();
                  return nameLower.contains('buffet') &&
                      (nameLower.contains('người lớn') ||
                          nameLower.contains('nguoi lon'));
                },
                orElse: () => ProductModel(
                  id: '0',
                  name: 'Vé Buffet Người Lớn',
                  price: 0,
                  categoryId: '',
                  isAvailable: true,
                ),
              );
              final prodChild = _productController.products.firstWhere(
                (p) {
                  final nameLower = p.name.toLowerCase();
                  return nameLower.contains('buffet') &&
                      (nameLower.contains('trẻ em') ||
                          nameLower.contains('tre em'));
                },
                orElse: () => ProductModel(
                  id: '0',
                  name: 'Vé Buffet Trẻ Em (6-11 tuổi)',
                  price: 0,
                  categoryId: '',
                  isAvailable: true,
                ),
              );

              // Chuẩn bị danh sách items mới nhất để đồng bộ lên Server
              if (adults > 0) {
                apiItems.add({
                  'product_id': int.tryParse(prodAdult.id) ?? 1,
                  'product_name': prodAdult.name,
                  'quantity': adults,
                  'unit_price': prodAdult.price,
                });
              }
              if (children > 0) {
                apiItems.add({
                  'product_id': int.tryParse(prodChild.id) ?? 2,
                  'product_name': prodChild.name,
                  'quantity': children,
                  'unit_price': prodChild.price,
                });
              }
              for (var item in orders) {
                final idVal = item['id'];
                final int? parsedId = idVal is int
                    ? idVal
                    : int.tryParse(idVal.toString());
                if (parsedId == null || parsedId <= 0) {
                  print(
                    "DEBUG CẢNH BÁO: Bỏ qua món '${item['name']}' vì product_id không hợp lệ: $idVal (type: ${idVal.runtimeType})",
                  );
                  continue;
                }
                apiItems.add({
                  'product_id': parsedId,
                  'product_name': item['name'],
                  'quantity': item['quantity'],
                  'unit_price': item['price'],
                });
              }
              print("DEBUG TỔNG HỢP ITEMS GỬI LÊN BACKEND: $apiItems");

              dialogListener = () {
                if (context.mounted) {
                  setDialogState(() {
                    // Triggers dialog rebuild on any controller updates (like payment complete)
                    if (_productController.paymentMethods.isNotEmpty &&
                        selectedMethodCode == null) {
                      final firstMethod =
                          _productController.paymentMethods.first;
                      selectedMethodCode = firstMethod.code;
                      selectedMethodName = firstMethod.name;

                      if (firstMethod.code != 'cash') {
                        final currentInvId = table['invoice_id']?.toString();
                        if (currentInvId != null) {
                          _productController.createCheckoutLink(
                            invoiceId: currentInvId,
                            paymentMethodId: firstMethod.id.toString(),
                          );
                        }
                      }
                    }
                  });
                }
              };
              if (!isListenerRegistered) {
                _productController.addListener(dialogListener!);
                isListenerRegistered = true;
              }

              final int calculatedTax = (baseTotal * 0.10).round();
              final int calculatedService = 0;

              final existingInvoiceId = table['invoice_id'];
              // Nếu có món gọi thêm → luôn tạo HĐ nháp mới với đầy đủ tất cả món
              // Nếu không có món gọi thêm → tái sử dụng hóa đơn cũ
              if (existingInvoiceId != null && orders.isEmpty) {
                // Không có món gọi thêm → tái sử dụng hóa đơn từ lúc mở bàn
                serverInvoice = InvoiceModel(
                  id: int.parse(existingInvoiceId.toString()),
                  invoiceCode: table['invoice_code']?.toString() ?? '',
                  employeeId: 14,
                  branchId: 1,
                  memberId: memberInfo != null
                      ? int.tryParse(memberInfo!['id'].toString())
                      : null,
                  tableNumber: table['name'].toString(),
                  subTotal: baseTotal,
                  discountAmount: discountAmount,
                  voucherDiscount: 0,
                  finalAmount: grandTotal + calculatedTax,
                  pointsEarned: pointsEarned,
                  pointsMultiplier: memberInfo != null
                      ? (memberInfo!['pointMultiplier'] as num).toInt()
                      : 1,
                  status: 'DRAFT',
                  taxAmount: calculatedTax,
                  serviceCharge: calculatedService,
                  createdAt: DateTime.now().toIso8601String(),
                  updatedAt: DateTime.now().toIso8601String(),
                  items: apiItems
                      .map(
                        (item) => InvoiceItemModel(
                          id: 0,
                          invoiceId: int.parse(existingInvoiceId.toString()),
                          productId: item['product_id'] as int,
                          productName: item['product_name'] as String,
                          quantity: item['quantity'] as int,
                          unitPrice: item['unit_price'] as int,
                        ),
                      )
                      .toList(),
                );

                // Join vào room socket của hóa đơn đã có
                SocketService.joinInvoice(serverInvoice!.id);

                // Tải danh sách phương thức thanh toán
                _productController.fetchPaymentMethods();
              } else {
                // Có món gọi thêm HOẶC chưa có hóa đơn nháp
                // → Tạo HĐ nháp mới chứa đầy đủ tất cả món (buffet + gọi thêm)
                print(
                  "DEBUG MỞ DIALOG THANH TOÁN: Tạo HĐ nháp mới với ${apiItems.length} món = $apiItems",
                );
                _productController
                    .createDraftInvoice(
                      memberId: memberInfo != null
                          ? memberInfo!['id'] as int?
                          : null,
                      tableNumber: table['name'],
                      taxAmount: calculatedTax,
                      serviceCharge: calculatedService,
                      pointsMultiplier:
                          memberInfo != null &&
                              memberInfo!['pointMultiplier'] != null
                          ? (memberInfo!['pointMultiplier'] as num).toInt()
                          : 1,
                      items: apiItems,
                    )
                    .then((invoice) {
                      if (invoice != null) {
                        table['invoice_id'] = invoice.id;
                        table['invoice_code'] = invoice.invoiceCode;

                        // Join vào room socket mới nhất của hóa đơn vừa tạo
                        SocketService.joinInvoice(invoice.id);

                        // Lưu trạng thái bàn vào SharedPreferences
                        _saveTablesState();

                        // Cập nhật Widget cha
                        setState(() {});

                        setDialogState(() {
                          serverInvoice = invoice;
                        });
                      }

                      // Tải danh sách phương thức thanh toán
                      _productController.fetchPaymentMethods();
                    });
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF161615),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: const Color(0xFFFED876).withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFED876).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFFFED876),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Thanh toán ${table['name']}',
                    style: const TextStyle(
                      color: Color(0xFFFED876),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              content: Container(
                width: 480,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // 1. TÓM TẮT HÓA ĐƠN
                      const Text(
                        'CHI TIẾT HÓA ĐƠN:',
                        style: TextStyle(
                          color: Color(0xFFFED876),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1D),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFED876).withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              'Buffet người lớn ($adults khách)',
                              '${(invoiceDetails['costAdult'] as int).toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                            ),
                            if (children > 0) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Divider(color: Color(0xFF2E2E2D), height: 1),
                              ),
                              _buildDetailRow(
                                'Buffet trẻ em ($children khách)',
                                '${(invoiceDetails['costChild'] as int).toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                              ),
                            ],
                            if (invoiceDetails['costSurcharge'] > 0) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Divider(color: Color(0xFF2E2E2D), height: 1),
                              ),
                              _buildDetailRow(
                                invoiceDetails['surchargeType'],
                                '${(invoiceDetails['costSurcharge'] as int).toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Món gọi thêm
                            ],
                          ),
                        ),
                      ],
                      _buildDetailRow(
                        'Tạm tính',
                        '${(baseTotal - (invoiceDetails['costSurcharge'] as int)).toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                      ),
                      _buildDetailRow(
                        invoiceDetails['costSurcharge'] > 0
                            ? invoiceDetails['surchargeType']
                            : 'Phụ thu',
                        '${(invoiceDetails['costSurcharge'] as int).toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                      ),
                      const Divider(color: Color(0xFF333332), height: 24),

                      // 2. KHUYẾN MÃI & THÀNH VIÊN (Luôn hiển thị)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'VOUCHER & THÀNH VIÊN:',
                              style: TextStyle(
                                color: Color(0xFF7A704A),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (appliedVoucher != null || memberInfo != null)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6B5805),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Đã áp dụng',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Ô nhập Voucher
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: voucherController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Nhập mã giảm giá (Voucher)',
                                hintStyle: const TextStyle(
                                  color: Colors.white24,
                                  fontSize: 13,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF1E1E1E),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF333332),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFED876),
                                  ),
                                ),
                                errorText: voucherError,
                                errorStyle: const TextStyle(
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 42,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFED876),
                                foregroundColor: const Color(0xFF1E1E1E),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                final code = voucherController.text
                                    .trim()
                                    .toUpperCase();
                                setDialogState(() {
                                  if (code.isEmpty) {
                                    voucherError = 'Chưa nhập mã';
                                    return;
                                  }
                                  if (code == 'BUFFET10') {
                                    appliedVoucher = code;
                                    discountAmount = (baseTotal * 0.1).round();
                                    voucherError = null;
                                  } else if (code == 'GIAM50K') {
                                    appliedVoucher = code;
                                    discountAmount = 50000;
                                    voucherError = null;
                                  } else {
                                    voucherError = 'Mã không tồn tại';
                                  }
                                });
                              },
                              child: const Text(
                                'Áp dụng',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Ô nhập thành viên (SĐT)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Nhập SĐT thành viên tích điểm',
                                hintStyle: const TextStyle(
                                  color: Colors.white24,
                                  fontSize: 13,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF1E1E1E),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF333332),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFED876),
                                  ),
                                ),
                                errorText: memberError,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 42,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6B5805),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final phone = phoneController.text.trim();
                                if (phone.isEmpty) {
                                  setDialogState(() {
                                    memberError = 'Chưa nhập SĐT';
                                  });
                                  return;
                                }

                                // Show loader in button or show dialog loader
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFFED876),
                                    ),
                                  ),
                                );

                                final member = await _productController
                                    .searchMemberByPhone(phone);

                                if (context.mounted) {
                                  Navigator.pop(
                                    context,
                                  ); // Close loading indicator
                                }

                                if (member != null) {
                                  setDialogState(() {
                                    memberInfo = {
                                      'id': member.id,
                                      'name': member.fullName,
                                      'rank': member.tierName,
                                      'points': member.currentPoints,
                                      'pointMultiplier': member.pointMultiplier,
                                    };
                                    memberError = null;
                                  });

                                  // Update draft invoice with member id
                                  final int calculatedTax =
                                      ((invoiceDetails['totalCost'] as int) *
                                              0.10)
                                          .round();
                                  final int calculatedService = 0;

                                  // Link member to the existing draft invoice instead of creating a new one
                                  final InvoiceModel? updatedInvoice;
                                  final currentInvId =
                                      table['invoice_id']?.toString() ??
                                      serverInvoice?.id.toString();
                                  if (currentInvId != null) {
                                    updatedInvoice = await _productController
                                        .linkMember(
                                          invoiceId: currentInvId,
                                          memberId: member.id,
                                        );
                                  } else {
                                    // Fallback to createDraftInvoice if no invoice exists yet
                                    updatedInvoice = await _productController
                                        .createDraftInvoice(
                                          memberId: member.id,
                                          tableNumber: table['name'],
                                          taxAmount: calculatedTax,
                                          serviceCharge: calculatedService,
                                          pointsMultiplier: member
                                              .pointMultiplier
                                              .toInt(),
                                          items: apiItems,
                                        );
                                  }

                                  if (updatedInvoice != null) {
                                    final actualInvoice = updatedInvoice;
                                    setDialogState(() {
                                      serverInvoice = actualInvoice;
                                      table['invoice_id'] = actualInvoice.id;
                                      table['invoice_code'] =
                                          actualInvoice.invoiceCode;
                                    });
                                    _saveTablesState();
                                    setState(() {});

                                    // Refresh checkout link if online payment is selected
                                    if (selectedMethodCode != null &&
                                        selectedMethodCode != 'cash') {
                                      final selectedMethod = _productController
                                          .paymentMethods
                                          .firstWhere(
                                            (m) => m.code == selectedMethodCode,
                                          );
                                      _productController.createCheckoutLink(
                                        invoiceId: actualInvoice.id.toString(),
                                        paymentMethodId: selectedMethod.id
                                            .toString(),
                                      );
                                    }
                                  }
                                } else {
                                  setDialogState(() {
                                    memberError =
                                        _productController.errorMessage ??
                                        'Không tìm thấy thành viên';
                                    memberInfo = null;
                                  });
                                }
                              },
                              child: const Text('Tìm'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Hoặc dùng mã QR:',
                            style: TextStyle(
                              color: Color(0xFF7A704A),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              showQrCode
                                  ? Icons.qr_code_scanner_rounded
                                  : Icons.qr_code_2_rounded,
                              color: const Color(0xFFFED876),
                              size: 18,
                            ),
                            label: Text(
                              showQrCode ? 'Ẩn mã QR' : 'Hiển thị mã QR',
                              style: const TextStyle(
                                color: Color(0xFFFED876),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                showQrCode = !showQrCode;
                              });
                            },
                          ),
                        ],
                      ),
                      if (showQrCode) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: QrImageView(
                              data:
                                  'https://tivibuffet.com/loyalty?tableId=${table['id']}&tableName=${Uri.encodeComponent(table['name'])}&total=$grandTotal&points=$pointsEarned',
                              version: QrVersions.auto,
                              size: 160.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(
                                0xFF6B5805,
                              ).withValues(alpha: 0.2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(
                                  color: Color(0xFFFED876),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.phonelink_ring_rounded,
                              size: 14,
                              color: Color(0xFFFED876),
                            ),
                            label: const Text(
                              '[GIẢ LẬP] Khách quét mã',
                              style: TextStyle(
                                color: Color(0xFFFED876),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                memberInfo = {
                                  'name': 'Nguyễn Văn A',
                                  'rank': 'Hạng Vàng',
                                  'points': 1500,
                                };
                                memberError = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            'Quét mã sẽ kích hoạt mở App Khách hàng & lưu thông tin vào hóa đơn',
                            style: TextStyle(
                              color: Color(0xFF7A704A),
                              fontSize: 11,
                            ),
                          ),
                        ),

                        // Hiển thị thông tin thành viên và tích lũy điểm
                        if (memberInfo != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF6B5805,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(
                                  0xFF6B5805,
                                ).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Khách hàng: ${memberInfo!['name']}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      memberInfo!['rank'],
                                      style: const TextStyle(
                                        color: Color(0xFFFED876),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Điểm hiện tại: ${memberInfo!['points']} điểm',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],

                      const Divider(color: Color(0xFF333332), height: 24),

                      // 3. TỔNG HỢP THANH TOÁN
                      const Text(
                        'TỔNG HỢP THANH TOÁN:',
                        style: TextStyle(
                          color: Color(0xFF7A704A),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Thuế (VAT 10%)',
                        '${(serverInvoice?.taxAmount ?? (grandTotal * 0.10).round()).toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                      ),
                      if (discountAmount > 0 ||
                          (serverInvoice != null &&
                              (serverInvoice!.discountAmount > 0 ||
                                  serverInvoice!.voucherDiscount > 0))) ...[
                        _buildDetailRow(
                          'Giảm giá ${appliedVoucher != null ? "(Voucher: $appliedVoucher)" : ""}',
                          '- ${((serverInvoice?.discountAmount ?? 0) + (serverInvoice?.voucherDiscount ?? 0) + discountAmount).toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                          valueColor: Colors.redAccent,
                        ),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tổng thanh toán:',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${(((serverInvoice != null) ? (serverInvoice!.finalAmount - discountAmount) : (grandTotal + (grandTotal * 0.10).round())) < 0 ? 0 : ((serverInvoice != null) ? (serverInvoice!.finalAmount - discountAmount) : (grandTotal + (grandTotal * 0.10).round()))).toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                            style: const TextStyle(
                              color: Color(0xFFFED876),
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),

                      const Divider(color: Color(0xFF333332), height: 24),

                      // 4. PHƯƠNG THỨC THANH TOÁN
                      const Text(
                        'PHƯƠNG THỨC THANH TOÁN:',
                        style: TextStyle(
                          color: Color(0xFF7A704A),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _productController.isLoading &&
                              _productController.paymentMethods.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFED876),
                                ),
                              ),
                            )
                          : _productController.errorMessage != null &&
                                _productController.paymentMethods.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Text(
                                  'Lỗi: ${_productController.errorMessage}',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : Column(
                              children:
                                  _productController.paymentMethods.isEmpty
                                  ? [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8.0,
                                        ),
                                        child: Text(
                                          'Không có phương thức thanh toán nào khả dụng',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ]
                                  : _productController.paymentMethods.map((
                                      PaymentMethodModel method,
                                    ) {
                                      final isSelected =
                                          selectedMethodCode == method.code;
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(
                                                  0xFF6B5805,
                                                ).withValues(alpha: 0.15)
                                              : const Color(0xFF1E1E1E),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFFFED876)
                                                : const Color(0xFF333332),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: RadioListTile<String>(
                                          value: method.code,
                                          groupValue: selectedMethodCode,
                                          activeColor: const Color(0xFFFED876),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ),
                                          title: Text(
                                            method.name,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : const Color(0xFF7A704A),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setDialogState(() {
                                                selectedMethodCode = val;
                                                selectedMethodName =
                                                    method.name;
                                                if (val != 'cash') {
                                                  _productController
                                                      .clearCheckoutData();
                                                  final currentInvId =
                                                      table['invoice_id']
                                                          ?.toString();
                                                  if (currentInvId != null) {
                                                    _productController
                                                        .createCheckoutLink(
                                                          invoiceId:
                                                              currentInvId,
                                                          paymentMethodId:
                                                              method.id
                                                                  .toString(),
                                                        );
                                                  }
                                                } else {
                                                  _productController
                                                      .clearCheckoutData();
                                                }
                                              });
                                            }
                                          },
                                        ),
                                      );
                                    }).toList(),
                            ),
                      if (selectedMethodCode != null &&
                          selectedMethodCode != 'cash') ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF333332)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'MÃ QR THANH TOÁN ONLINE (PAYOS):',
                                style: TextStyle(
                                  color: Color(0xFFFED876),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              _productController.isLoading
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 24.0,
                                        ),
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFFED876),
                                        ),
                                      ),
                                    )
                                  : _productController.errorMessage != null
                                  ? Text(
                                      'Lỗi tạo mã QR: ${_productController.errorMessage}',
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    )
                                  : _productController.checkoutData == null
                                  ? const Text(
                                      'Đang khởi tạo mã thanh toán...',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    )
                                  : Column(
                                      children: [
                                        Center(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: QrImageView(
                                              data: _productController
                                                  .checkoutData!
                                                  .qrCode,
                                              version: QrVersions.auto,
                                              size: 180.0,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Số tiền: ${(((serverInvoice != null) ? (serverInvoice!.finalAmount - discountAmount) : (grandTotal + (grandTotal * 0.10).round())) < 0 ? 0 : ((serverInvoice != null) ? (serverInvoice!.finalAmount - discountAmount) : (grandTotal + (grandTotal * 0.10).round()))).toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                                          style: const TextStyle(
                                            color: Color(0xFFFED876),
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Khách hàng quét mã này để thanh toán',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Mã QR Code VietQR | Hoá đơn: ${_productController.checkoutData!.invoiceId}',
                                          style: const TextStyle(
                                            color: Color(0xFFFED876),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                // Ẩn nút Hủy khi PayOS đã thanh toán thành công
                if (!_productController.paidTables.contains(
                  table['name'].toString().trim().toLowerCase(),
                ))
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Hủy',
                      style: TextStyle(color: Color(0xFF555555)),
                    ),
                  ),

                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _productController.paidTables.contains(
                          table['name'].toString().trim().toLowerCase(),
                        )
                        ? const Color(
                            0xFF2E7D32,
                          ) // Xanh lá khi đã thanh toán PayOS
                        : (selectedMethodCode == null ||
                              selectedMethodCode == 'cash')
                        ? const Color(0xFFFED876) // Vàng cho tiền mặt
                        : Colors.grey, // Xám khi đang chờ PayOS
                    foregroundColor:
                        _productController.paidTables.contains(
                          table['name'].toString().trim().toLowerCase(),
                        )
                        ? Colors.white
                        : (selectedMethodCode == null ||
                              selectedMethodCode == 'cash')
                        ? const Color(0xFF1E1E1E)
                        : Colors.white30,
                  ),
                  onPressed:
                      (selectedMethodCode == null ||
                          selectedMethodCode == 'cash' ||
                          _productController.paidTables.contains(
                            table['name'].toString().trim().toLowerCase(),
                          ))
                      ? () async {
                          // Tìm sản phẩm Buffet từ API để lấy tên và giá thực tế
                          final prodAdult = _productController.products
                              .firstWhere(
                                (p) {
                                  final nameLower = p.name.toLowerCase();
                                  return nameLower.contains('buffet') &&
                                      (nameLower.contains('người lớn') ||
                                          nameLower.contains('nguoi lon'));
                                },
                                orElse: () => ProductModel(
                                  id: '0',
                                  name: 'Vé Buffet Người Lớn',
                                  price: 0,
                                  categoryId: '',
                                  isAvailable: true,
                                ),
                              );
                          final prodChild = _productController.products
                              .firstWhere(
                                (p) {
                                  final nameLower = p.name.toLowerCase();
                                  return nameLower.contains('buffet') &&
                                      (nameLower.contains('trẻ em') ||
                                          nameLower.contains('tre em'));
                                },
                                orElse: () => ProductModel(
                                  id: '0',
                                  name: 'Vé Buffet Trẻ Em (6-11 tuổi)',
                                  price: 0,
                                  categoryId: '',
                                  isAvailable: true,
                                ),
                              );

                          // Chuẩn bị danh sách items gửi lên API dựa vào Buffet và Món gọi thêm
                          final List<Map<String, dynamic>> apiItems = [];

                          // Thêm Buffet người lớn
                          if (adults > 0) {
                            apiItems.add({
                              'product_id': int.tryParse(prodAdult.id) ?? 1,
                              'product_name': prodAdult.name,
                              'quantity': adults,
                              'unit_price': prodAdult.price,
                            });
                          }
                          // Thêm Buffet trẻ em
                          if (children > 0) {
                            apiItems.add({
                              'product_id': int.tryParse(prodChild.id) ?? 2,
                              'product_name': prodChild.name,
                              'quantity': children,
                              'unit_price': prodChild.price,
                            });
                          }
                          // Thêm các món gọi thêm trong orders
                          for (var item in orders) {
                            final idVal = item['id'];
                            apiItems.add({
                              'product_id': idVal is int
                                  ? idVal
                                  : (int.tryParse(idVal.toString()) ?? idVal),
                              'product_name': item['name'],
                              'quantity': item['quantity'],
                              'unit_price': item['price'],
                            });
                          }

                          // Hiển thị vòng tải trong lúc gọi API gửi dữ liệu hóa đơn nháp lên backend
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFFED876),
                              ),
                            ),
                          );

                          final currentDetails = _calculateInvoiceDetails(
                            adults,
                            children,
                            orders,
                          );
                          final int currentBaseTotal =
                              currentDetails['totalCost'] as int;
                          final int calculatedTax = (currentBaseTotal * 0.10)
                              .round();
                          final int calculatedService = 0;

                          // Gọi API tạo hóa đơn nháp thực tế trên backend nếu chưa có hoặc có món gọi thêm cần đồng bộ
                          final InvoiceModel? nullableInvoice;
                          if (serverInvoice != null && orders.isEmpty) {
                            nullableInvoice = serverInvoice;
                          } else {
                            nullableInvoice = await _productController
                                .createDraftInvoice(
                                  memberId: memberInfo != null
                                      ? memberInfo!['id'] as int?
                                      : null,
                                  tableNumber: table['name'],
                                  taxAmount: calculatedTax,
                                  serviceCharge: calculatedService,
                                  pointsMultiplier:
                                      memberInfo != null &&
                                          memberInfo!['pointMultiplier'] != null
                                      ? (memberInfo!['pointMultiplier'] as num)
                                            .toInt()
                                      : 1,
                                  items: apiItems,
                                );
                          }

                          if (context.mounted) {
                            Navigator.pop(context); // Đóng vòng tải loading
                          }

                          if (nullableInvoice == null) {
                            if (context.mounted) {
                              CustomNotification.show(
                                context,
                                message:
                                    _productController.errorMessage ??
                                    'Không thể lưu hóa đơn nháp lên Server',
                                backgroundColor: Colors.redAccent,
                                icon: Icons.error_outline,
                              );
                            }
                            return; // Dừng lại không đóng bàn nếu gọi API thất bại
                          }

                          final invoice = nullableInvoice;
                          table['invoice_id'] = invoice.id;
                          table['invoice_code'] = invoice.invoiceCode;

                          // Nếu là phương thức thanh toán tiền mặt (cash), gọi API checkout để Backend hoàn tất hóa đơn (PAID) và cộng điểm
                          if (selectedMethodCode == 'cash') {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFED876),
                                ),
                              ),
                            );

                            final cashMethod = _productController.paymentMethods
                                .firstWhere(
                                  (m) => m.code == 'cash',
                                  orElse: () =>
                                      _productController.paymentMethods.first,
                                );

                            final checkoutResult = await _productController
                                .createCheckoutLink(
                                  invoiceId: invoice.id.toString(),
                                  paymentMethodId: cashMethod.id.toString(),
                                );

                            if (!context.mounted) return;
                            Navigator.pop(context); // Đóng vòng tải checkout

                            if (checkoutResult == null) {
                              CustomNotification.show(
                                context,
                                message:
                                    _productController.errorMessage ??
                                    'Không thể xác nhận thanh toán tiền mặt trên Server',
                                backgroundColor: Colors.redAccent,
                                icon: Icons.error_outline,
                              );
                              return; // Dừng lại không đóng bàn nếu checkout tiền mặt thất bại
                            }
                          }

                          final completedInvoice =
                              _productController.paidInvoices[table['name']
                                  .toString()
                                  .trim()
                                  .toLowerCase()];
                          final finalPoints =
                              completedInvoice?.pointsEarned ??
                              invoice.pointsEarned;
                          final isPaid =
                              completedInvoice != null ||
                              _productController.paidTables.contains(
                                table['name'].toString().trim().toLowerCase(),
                              );

                          String snackText = isPaid
                              ? 'Đã hoàn tất thanh toán hóa đơn (${invoice.invoiceCode}) thành công cho ${table['name']} bằng $selectedMethodName! Tổng tiền: ${invoice.finalAmount.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ.'
                              : 'Đã lưu hóa đơn nháp (${invoice.invoiceCode}) thành công cho ${table['name']} bằng $selectedMethodName! Tổng cộng: ${invoice.finalAmount.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ.';
                          if (memberInfo != null) {
                            snackText +=
                                ' Tích lũy +$finalPoints điểm cho thành viên ${memberInfo!['name']}.';
                          }

                          // Kết nối Socket.io và tham gia phòng của hóa đơn (room: invoice_invoiceId)
                          // để phục vụ việc lắng nghe sự kiện thanh toán online real-time.
                          SocketService.joinInvoice(invoice.id);

                          // Chuẩn bị danh sách món ăn cho lịch sử hóa đơn
                          final List<Map<String, dynamic>> invoiceItems = [];
                          if (adults > 0) {
                            invoiceItems.add({
                              'name': 'Vé Buffet Người Lớn',
                              'price': prodAdult.price,
                              'quantity': adults,
                            });
                          }
                          if (children > 0) {
                            invoiceItems.add({
                              'name': 'Vé Buffet Trẻ Em (6-11 tuổi)',
                              'price': prodChild.price,
                              'quantity': children,
                            });
                          }
                          if (currentDetails['costSurcharge'] > 0) {
                            invoiceItems.add({
                              'name':
                                  currentDetails['surchargeType'] ?? 'Phụ thu',
                              'price':
                                  currentDetails['surchargePerGuest'] as int,
                              'quantity': (adults + children),
                            });
                          }
                          for (final o in orders) {
                            invoiceItems.add({
                              'name': o['name']?.toString() ?? '',
                              'price': o['price'] as int,
                              'quantity': o['quantity'] as int,
                            });
                          }

                          _productController.clearTablePaidStatus(
                            table['name'],
                          );
                          setState(() {
                            _invoices.insert(0, {
                              'id': invoice.invoiceCode.isEmpty
                                  ? 'HD-${invoice.id}'
                                  : invoice.invoiceCode,
                              'table': table['name'],
                              'time':
                                  "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} - ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}",
                              'amount': invoice.finalAmount.toInt(),
                              'guests': (adults + children),
                              'status': isPaid ? 'paid' : 'draft',
                              'paymentMethod': selectedMethodName,
                              'tax': calculatedTax,
                              'serviceCharge': calculatedService,
                              'pointsEarned': finalPoints,
                              'member': memberInfo != null
                                  ? {
                                      'name': memberInfo!['name'],
                                      'phone': memberInfo!['phone'],
                                    }
                                  : null,
                              'items': invoiceItems,
                            });

                            _tables[index]['status'] = 'empty';
                            _tables[index]['guests'] = 0;
                            _tables[index]['adults'] = 0;
                            _tables[index]['children'] = 0;
                            _tables[index]['timeStarted'] = null;
                            _tables[index]['orders'] = <Map<String, dynamic>>[];
                            _tables[index]['invoice_id'] = null;
                            _tables[index]['invoice_code'] = null;
                          });
                          _saveTablesState();

                          if (context.mounted) {
                            Navigator.pop(context); // Đóng Dialog xác nhận
                          }

                          if (context.mounted) {
                            CustomNotification.show(
                              context,
                              message: snackText,
                              backgroundColor: const Color(0xFF6B5805),
                              icon: Icons.check_circle_outline,
                            );
                          }
                        }
                      : null,
                  child: Text(
                    _productController.paidTables.contains(
                          table['name'].toString().trim().toLowerCase(),
                        )
                        ? 'Hoàn thành' // Đã thanh toán PayOS
                        : (selectedMethodCode != null &&
                              selectedMethodCode != 'cash')
                        ? 'Chờ chuyển khoản...' // Đang chờ PayOS
                        : 'Xác nhận & Đóng bàn', // Tiền mặt hoặc chưa chọn
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      if (_activeDialogTable == table['name']) {
        _activeDialogTable = null;
      }
      if (dialogListener != null) {
        _productController.removeListener(dialogListener!);
      }
    });
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color valueColor = Colors.white,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF7A704A))),
          Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _authenticateAndShowOffProductManager() {
    final controller = TextEditingController();
    String? pinError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF222221),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF333332), width: 1),
              ),
              title: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, color: Color(0xFFFED876)),
                  SizedBox(width: 10),
                  Text(
                    'Quyền quản lý món',
                    style: TextStyle(
                      color: Color(0xFFFED876),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Vui lòng nhập mã PIN nhân viên để mở kho kho/quản lý món ăn.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF7A704A)),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFFED876)),
                      ),
                      errorText: pinError,
                      errorStyle: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(
                      color: Color(0xFF7A704A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFED876),
                    foregroundColor: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    final pin = controller.text.trim();
                    if (pin == '1234') {
                      Navigator.pop(context);
                      _showOffProductManagerBottomSheet();
                    } else {
                      setDialogState(() {
                        pinError = 'Mã PIN không đúng!';
                      });
                    }
                  },
                  child: const Text(
                    'Xác nhận',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showOffProductManagerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151514),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ListenableBuilder(
          listenable: _productController,
          builder: (context, _) {
            if (_productController.products.isEmpty) {
              return const SizedBox(
                height: 250,
                child: Center(
                  child: Text(
                    'Đang tải danh sách món ăn từ server...',
                    style: TextStyle(color: Color(0xFF7A704A)),
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.no_meals_rounded,
                            color: Color(0xFFFED876),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'BẬT/TẮT MÓN ĂN (OFF MÓN)',
                            style: TextStyle(
                              color: Color(0xFFFED876),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Gạt công tắc bên cạnh để TẮT món ăn tạm thời khi bếp hết hàng. Khách hàng sẽ không thể chọn món này.',
                    style: TextStyle(color: Color(0xFF7A704A), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _productController.products.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: Color(0xFF232322)),
                      itemBuilder: (context, idx) {
                        final product = _productController.products[idx];
                        final isOff = _productController.offProductIds.contains(
                          product.id,
                        );

                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: const Color(0xFFFED876),
                          inactiveTrackColor: Colors.redAccent.withValues(
                            alpha: 0.2,
                          ),
                          inactiveThumbColor: Colors.redAccent,
                          title: Text(
                            product.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${product.price.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                            style: const TextStyle(
                              color: Color(0xFF7A704A),
                              fontSize: 12,
                            ),
                          ),
                          // Switch hiển thị TRẠNG THÁI BÁN (ON = Đang bán, OFF = Đang ngưng)
                          // nên value sẽ là !isOff (true nếu đang bán, false nếu bị off)
                          value: !isOff,
                          onChanged: (bool value) {
                            _productController.toggleProductAvailability(
                              product.id,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF222221),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF333332), width: 1),
          ),
          title: const Row(
            children: [
              Icon(Icons.settings, color: Color(0xFFFED876)),
              SizedBox(width: 10),
              Text(
                'Cài đặt thiết bị',
                style: TextStyle(
                  color: Color(0xFFFED876),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.no_meals_rounded,
                  color: Color(0xFFFED876),
                ),
                title: const Text(
                  'Quản lý bật/tắt món ăn',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Tắt món tạm thời khi bếp hết hàng',
                  style: TextStyle(color: Color(0xFF555555)),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF7A704A),
                ),
                onTap: () {
                  Navigator.pop(context); // Đóng Cài đặt chính
                  _authenticateAndShowOffProductManager();
                },
              ),
              const Divider(color: Color(0xFF333332)),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  'Đăng xuất tài khoản',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  // Hiển thị vòng tải loading trong lúc gọi API đăng xuất
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFED876),
                      ),
                    ),
                  );

                  // Gọi API đăng xuất thông qua LoginController
                  await sl<LoginController>().logout();

                  if (context.mounted) {
                    Navigator.pop(context); // Đóng vòng tải loading
                    Navigator.pop(context); // Đóng Dialog cài đặt
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StaffLoginScreen(),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Đóng',
                style: TextStyle(color: Color(0xFF7A704A)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111110),
      body: DotGridBackgroundWithVignette(
        backgroundColor: const Color(0xFF111110),
        dotColor: const Color(0xFF272726),
        dotRadius: 1.1,
        spacing: 20.0,
        child: Row(
        children: [
          // Sidebar bên trái
          Container(
            width: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1C1C1B), Color(0xFF141413)],
              ),
              border: Border(
                right: BorderSide(
                  color: const Color(0xFFFED876).withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 20),
                    // Logo TV
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B7200), Color(0xFF6B5805)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFED876).withValues(alpha: 0.2),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'docs/logo_tivi_buffet_blue_gold.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.tv,
                              color: Colors.white,
                              size: 26,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Tab Sơ đồ bàn
                    _buildSidebarItem(
                      index: 0,
                      icon: Icons.grid_view_rounded,
                      label: 'Sơ đồ',
                    ),
                    const SizedBox(height: 8),
                    // Tab Lịch sử hóa đơn
                    _buildSidebarItem(
                      index: 1,
                      icon: Icons.receipt_long_rounded,
                      label: 'Hóa đơn',
                    ),
                  ],
                ),
                Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A29),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.settings_rounded,
                          color: Color(0xFF7A704A),
                          size: 20,
                        ),
                        onPressed: _showSettings,
                        tooltip: 'Cài đặt',
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),

          // Vùng hiển thị nội dung chính
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1C1C1B), Color(0xFF161615)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFFED876).withValues(alpha: 0.12),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFED876),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _selectedTab == 0 ? 'Sơ đồ bàn' : 'Lịch sử hóa đơn',
                            style: const TextStyle(
                              color: Color(0xFFFED876),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedTab == 0
                                ? '• ${_tables.where((t) => t['status'] == 'serving').length}/${_tables.length} bàn đang dùng'
                                : '• ${_invoices.where((inv) => inv['status'] == 'paid').length} đã thanh toán',
                            style: const TextStyle(
                              color: Color(0xFF7A704A),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedTab == 0)
                        Row(
                          children: ['Tầng 1'].map((area) {
                            final isSelected = _selectedArea == area;
                            return Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF6B5805).withValues(alpha: 0.25)
                                      : const Color(0xFF1E1E1D),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFFED876).withValues(alpha: 0.6)
                                        : const Color(0xFF2E2E2D),
                                  ),
                                ),
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedArea = area),
                                  child: Text(
                                    area,
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFFFED876)
                                          : const Color(0xFF7A704A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),

                // Nội dung chính theo Tab
                Expanded(
                  child: _selectedTab == 0
                      ? _buildTableMap()
                      : _buildInvoiceHistory(),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTab == index;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Active indicator line bên trái
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 3,
              height: isSelected ? 44 : 0,
              margin: const EdgeInsets.only(left: 0),
              decoration: BoxDecoration(
                color: const Color(0xFFFED876),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6B5805).withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: isSelected
                          ? const Color(0xFFFED876)
                          : const Color(0xFF4A4A49),
                      size: 24,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFFED876)
                            : const Color(0xFF4A4A49),
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableMap() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: _tables.length,
      itemBuilder: (context, index) {
        final table = _tables[index];
        final status = table['status'];
        final tableName = table['name'] as String;
        final guests = table['guests'] as int? ?? 0;
        final isPaidTable = _productController.paidTables.contains(
          tableName.trim().toLowerCase(),
        );

        // ── Màu sắc theo trạng thái ──────────────────────────────────
        final bool isEmpty = status == 'empty';
        final bool isServing = status == 'serving';

        // Bàn đã thanh toán PayOS nhưng chưa đóng
        final Color accentColor = isPaidTable
            ? const Color(0xFF4CAF50)       // Xanh lá - đã TT
            : isServing
                ? const Color(0xFFFED876)   // Vàng - đang phục vụ
                : status == 'reserved'
                    ? const Color(0xFF7A9BC2) // Xanh - đặt trước
                    : const Color(0xFF444443); // Xám - trống

        final Color bgGradientStart = isPaidTable
            ? const Color(0xFF1B3A1E)
            : isServing
                ? const Color(0xFF2A2200)
                : status == 'reserved'
                    ? const Color(0xFF162233)
                    : const Color(0xFF1A1A1A);

        final Color bgGradientEnd = isPaidTable
            ? const Color(0xFF0F2211)
            : isServing
                ? const Color(0xFF1A1500)
                : status == 'reserved'
                    ? const Color(0xFF0D1620)
                    : const Color(0xFF141414);

        // ── Biểu tượng theo trạng thái ───────────────────────────────
        final IconData tableIcon = isPaidTable
            ? Icons.check_circle_rounded
            : isServing
                ? Icons.table_restaurant_rounded
                : status == 'reserved'
                    ? Icons.event_seat_rounded
                    : Icons.table_bar_outlined;

        // ── Thời gian phục vụ ─────────────────────────────────────────
        String timeText = '';
        String durationText = '';
        if (isServing && table['timeStarted'] != null) {
          final ts = table['timeStarted'];
          if (ts is DateTime) {
            timeText =
                '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
            final diff = DateTime.now().difference(ts);
            final h = diff.inHours;
            final m = diff.inMinutes % 60;
            durationText = h > 0 ? '${h}g${m.toString().padLeft(2, '0')}p' : '${m}p';
          } else {
            timeText = ts.toString();
          }
        }

        return GestureDetector(
          onTap: () {
            if (status == 'empty') {
              _openTable(index);
            } else if (status == 'serving') {
              _viewTableDetail(index);
            }
          },
          child: MouseRegion(
            cursor: (isEmpty || isServing)
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bgGradientStart, bgGradientEnd],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: accentColor.withValues(alpha: isServing || isPaidTable ? 0.7 : 0.3),
                  width: isServing || isPaidTable ? 1.5 : 1.0,
                ),
                boxShadow: (isServing || isPaidTable)
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.15),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Stack(
                children: [
                  // ── Nội dung chính ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon + Tên bàn
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                tableIcon,
                                color: accentColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tableName,
                                style: TextStyle(
                                  color: isEmpty
                                      ? const Color(0xFF888887)
                                      : accentColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Số khách (khi đang phục vụ)
                        if (isServing) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.people_alt_rounded,
                                color: Color(0xFF7A704A),
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$guests khách',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Thời gian
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                color: Color(0xFF7A704A),
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeText,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                              if (durationText.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6B5805).withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    durationText,
                                    style: const TextStyle(
                                      color: Color(0xFFFED876),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ] else ...[
                          // Trống / Đặt trước
                          Text(
                            status == 'reserved' ? 'Đặt trước' : 'Trống',
                            style: TextStyle(
                              color: status == 'reserved'
                                  ? accentColor.withValues(alpha: 0.8)
                                  : const Color(0xFF555555),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Badge trạng thái (góc trên phải) ────────────────
                  if (isPaidTable)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Đã TT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    )
                  else if (isServing)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFED876),
                          shape: BoxShape.circle,
                        ),
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


  void _showInvoiceDetail(Map<String, dynamic> inv) {
    final isPaid = inv['status'] == 'paid';
    final List<dynamic> items = inv['items'] ?? [];
    final member = inv['member'];

    // Tìm sản phẩm Buffet để lấy thông tin hiển thị (nếu cần mockup in)
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF222221),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF333332), width: 1),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                inv['id'],
                style: const TextStyle(
                  color: Color(0xFFFED876),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isPaid
                      ? const Color(0xFF6B5805).withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isPaid ? const Color(0xFFFED876) : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Text(
                  isPaid ? 'ĐÃ THANH TOÁN' : 'HÓA ĐƠN NHÁP',
                  style: TextStyle(
                    color: isPaid ? const Color(0xFFFED876) : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            width: 400,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      'TIVI BUFFET',
                      style: TextStyle(
                        color: Color(0xFFFED876),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildDetailRow('Bàn phục vụ:', inv['table'] ?? ''),
                  _buildDetailRow('Thời gian lập:', inv['time'] ?? ''),
                  _buildDetailRow(
                    'Số lượng khách:',
                    '${inv['guests'] ?? 0} khách',
                  ),
                  _buildDetailRow(
                    'Hình thức:',
                    inv['paymentMethod'] ?? 'Chưa xác định',
                  ),
                  if (member != null) ...[
                    _buildDetailRow('Khách hàng:', member['name'] ?? ''),
                    _buildDetailRow('Số điện thoại:', member['phone'] ?? ''),
                    _buildDetailRow(
                      'Tích lũy:',
                      '+${inv['pointsEarned'] ?? 0} điểm',
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    '- - - - - - - - - - - - - - - - - - - - - - - - - -',
                    style: TextStyle(color: Color(0xFF333332), fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'DANH SÁCH MÓN ĂN',
                    style: TextStyle(
                      color: Color(0xFF7A704A),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Không có chi tiết món ăn',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    )
                  else
                    ...items.map((item) {
                      final price = item['price'] as int? ?? 0;
                      final qty = item['quantity'] as int? ?? 0;
                      final total = price * qty;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$qty x ${price.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                                    style: const TextStyle(
                                      color: Color(0xFF555555),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${total.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 10),
                  const Text(
                    '- - - - - - - - - - - - - - - - - - - - - - - - - -',
                    style: TextStyle(color: Color(0xFF333332), fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    'Phí dịch vụ:',
                    '${(inv['serviceCharge'] ?? 0).toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                  ),
                  _buildDetailRow(
                    'Thuế VAT (1%):',
                    '${(inv['tax'] ?? 0).toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '- - - - - - - - - - - - - - - - - - - - - - - - - -',
                    style: TextStyle(color: Color(0xFF333332), fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TỔNG CỘNG:',
                        style: TextStyle(
                          color: Color(0xFFFED876),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${(inv['amount'] ?? 0).toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                        style: const TextStyle(
                          color: Color(0xFFFED876),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutButton(
              onPressed: () {
                Navigator.pop(context);
                CustomNotification.show(
                  context,
                  message: 'Đang gửi yêu cầu in hóa đơn ${inv['id']}...',
                  backgroundColor: const Color(0xFF6B5805),
                  icon: Icons.print_rounded,
                );
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.print_rounded, color: Color(0xFFFED876), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'In hóa đơn',
                    style: TextStyle(color: Color(0xFFFED876)),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Đóng',
                style: TextStyle(color: Color(0xFF7A704A)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.07),
            const Color(0xFF161615),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent bar + icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceHistory() {
    final totalRevenue = _invoices
        .where((inv) => inv['status'] == 'paid')
        .fold<int>(0, (sum, inv) => sum + (inv['amount'] as int));
    final paidCount = _invoices.where((inv) => inv['status'] == 'paid').length;
    final draftCount = _invoices
        .where((inv) => inv['status'] == 'draft')
        .length;

    final filteredInvoices = _invoices.where((inv) {
      if (_selectedInvoiceFilter == 'paid') {
        return inv['status'] == 'paid';
      } else if (_selectedInvoiceFilter == 'draft') {
        return inv['status'] == 'draft';
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Khối Thống kê Tổng quan (Summary Cards)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'DOANH THU ĐÃ THU',
                  value:
                      '${totalRevenue.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                  icon: Icons.monetization_on_rounded,
                  color: const Color(0xFFFED876),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  title: 'HÓA ĐƠN HOÀN THÀNH',
                  value: '$paidCount hóa đơn',
                  icon: Icons.check_circle_rounded,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  title: 'HÓA ĐƠN NHÁP/TREO',
                  value: '$draftCount hóa đơn',
                  icon: Icons.assignment_rounded,
                  color: Colors.orangeAccent,
                ),
              ),
            ],
          ),
        ),

        // Thanh Bộ lọc (Filter Bar)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
          child: Row(
            children: [
              const Text(
                'Bộ lọc trạng thái:',
                style: TextStyle(
                  color: Color(0xFF7A704A),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              ...[
                {'label': 'Tất cả', 'value': 'all'},
                {'label': 'Đã thanh toán', 'value': 'paid'},
                {'label': 'Hóa đơn nháp', 'value': 'draft'},
              ].map((filter) {
                final isSelected = _selectedInvoiceFilter == filter['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(filter['label']!),
                    selected: isSelected,
                    selectedColor: const Color(0xFF6B5805),
                    backgroundColor: const Color(0xFF1E1E1E),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF7A704A),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFFFED876)
                            : const Color(0xFF2E2E2D),
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedInvoiceFilter = filter['value']!;
                        });
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        // Danh sách hóa đơn
        Expanded(
          child: filteredInvoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.receipt_long_rounded,
                        size: 64,
                        color: Color(0xFF333332),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedInvoiceFilter == 'all'
                            ? 'Chưa có hóa đơn nào được thực hiện'
                            : _selectedInvoiceFilter == 'paid'
                            ? 'Không tìm thấy hóa đơn đã thanh toán nào'
                            : 'Không tìm thấy hóa đơn nháp nào',
                        style: const TextStyle(
                          color: Color(0xFF7A704A),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: filteredInvoices.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final inv = filteredInvoices[index];
                    final isPaid = inv['status'] == 'paid';
                    final accentColor = isPaid
                        ? const Color(0xFFFED876)
                        : Colors.orangeAccent;

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _showInvoiceDetail(inv),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: isPaid
                                  ? [
                                      const Color(0xFF1E1C10),
                                      const Color(0xFF161514),
                                    ]
                                  : [
                                      const Color(0xFF1A1510),
                                      const Color(0xFF161514),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Icon trạng thái
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Icon(
                                  isPaid
                                      ? Icons.check_circle_rounded
                                      : Icons.pending_actions_rounded,
                                  color: accentColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Thông tin hóa đơn
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          inv['id'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Badge bàn
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6B5805).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFFFED876).withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            inv['table'] ?? '',
                                            style: const TextStyle(
                                              color: Color(0xFFFED876),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Badge phương thức
                                        if (inv['paymentMethod'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E2A1E),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.greenAccent.withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Text(
                                              inv['paymentMethod'],
                                              style: const TextStyle(
                                                color: Colors.greenAccent,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time_rounded,
                                          size: 11,
                                          color: Color(0xFF555555),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          inv['time'] ?? '',
                                          style: const TextStyle(
                                            color: Color(0xFF666665),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Icon(
                                          Icons.people_alt_rounded,
                                          size: 11,
                                          color: Color(0xFF555555),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${inv['guests'] ?? 0} khách',
                                          style: const TextStyle(
                                            color: Color(0xFF666665),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Số tiền + mũi tên
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${inv['amount'].toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                                    style: TextStyle(
                                      color: accentColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: const Color(0xFF444443),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}



class OutButton extends StatelessWidget {
  const OutButton({super.key, required this.onPressed, required this.child});
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFFED876)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      child: child,
    );
  }
}
