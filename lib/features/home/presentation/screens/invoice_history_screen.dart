import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  // Bộ lưu trữ bảo mật để lấy access_token của nhân viên
  final _storage = const FlutterSecureStorage();
  
  // Controller dùng để theo dõi sự kiện cuộn
  final ScrollController _scrollController = ScrollController();
  
  // Các trạng thái quản lý dữ liệu và UI
  final List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = false;
  bool _hasMore = true;
  static const String baseUrl = 'https://bistred-tryptic-peter.ngrok-free.dev/api';
  final String _apiUrl = '$baseUrl/invoice/my/today';
  String? _lastId;
  String? _errorMessage;



  @override
  void initState() {
    super.initState();
    _fetchInvoices(); // Tải dữ liệu trang đầu tiên
    _scrollController.addListener(_onScroll); // Lắng nghe cuộn trang
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Hàm lắng nghe sự kiện cuộn của ListView
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // Lấy vị trí cuộn hiện tại
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // Nếu cuộn cách đáy nhỏ hơn hoặc bằng 200px, không trong trạng thái đang tải và vẫn còn dữ liệu
    if (maxScroll - currentScroll <= 200 && !_isLoading && _hasMore) {
      _fetchInvoices();
    }
  }

  // Hàm tải dữ liệu hóa đơn từ API
  Future<void> _fetchInvoices({bool isRefresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (isRefresh) {
        _lastId = null; // Reset last_id khi làm mới trang
        _hasMore = true;
      }
    });

    try {
      // Đọc access_token từ Secure Storage giống như các API khác của app
      final token = await _storage.read(key: 'access_token');
      
      // Xây dựng URL API kèm theo tham số phân trang last_id (nếu có)
      String requestUrl = _apiUrl;
      if (_lastId != null) {
        requestUrl += '?last_id=$_lastId';
      }

      final response = await http.get(
        Uri.parse(requestUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true', // Bỏ qua trang cảnh báo của ngrok
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        // Lấy danh sách hóa đơn mới
        final List<dynamic> newRawInvoices = responseData['data'] ?? [];
        final List<Map<String, dynamic>> newInvoices = 
            newRawInvoices
                .map((item) => Map<String, dynamic>.from(item))
                .where((inv) => inv['status'] == 'COMPLETED')
                .toList();
        
        // Đọc thông tin phân trang từ API
        final pagination = responseData['pagination'];
        final bool hasMoreData = pagination != null ? (pagination['has_more'] ?? false) : false;
        final String? nextLastId = pagination != null ? pagination['last_id']?.toString() : null;

        setState(() {
          if (isRefresh) {
            _invoices.clear(); // Xóa sạch danh sách cũ khi pull-to-refresh
          }
          
          _invoices.addAll(newInvoices); // Cộng dồn dữ liệu mới vào danh sách hiện tại
          _hasMore = hasMoreData && nextLastId != null; // Cập nhật trạng thái còn dữ liệu hay không
          _lastId = nextLastId; // Lưu lại last_id phục vụ lần tải tiếp theo
          _isLoading = false;
        });
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Lấy danh sách hóa đơn thất bại (Mã lỗi ${response.statusCode})');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // Xử lý khi thực hiện hành động kéo để làm mới (Pull-to-refresh)
  Future<void> _handleRefresh() async {
    await _fetchInvoices(isRefresh: true);
  }

  // Định dạng hiển thị tiền tệ VNĐ dùng regex thuần Dart (Ví dụ: 100.000 đ)
  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0 đ';
    final str = amount.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '${str.replaceAllMapped(reg, (Match m) => '${m[1]}.')} đ';
  }

  // Định dạng hiển thị ngày giờ bằng xử lý chuỗi thuần Dart (Ví dụ: 15:30 - 19/06/2026)
  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dateTime = DateTime.parse(dateStr).toLocal();
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year;
      return '$hour:$minute - $day/$month/$year';
    } catch (e) {
      return dateStr;
    }
  }

  // Hàm chuyển đổi an toàn mọi kiểu dữ liệu động (String/num) thành kiểu num
  num _parseNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value) ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Tông màu chủ đạo Dark Mode sang trọng, đồng bộ với ứng dụng
    const scaffoldBgColor = Color(0xFF111110);
    const cardBgColor = Color(0xFF1A1A19);
    const accentColor = Color(0xFFFED876);
    const secondaryTextColor = Color(0xFF7A704A);

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: AppBar(
        backgroundColor: scaffoldBgColor,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: accentColor),
            SizedBox(width: 10),
            Text(
              'Lịch Sử Hóa Đơn',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: accentColor,
        backgroundColor: cardBgColor,
        onRefresh: _handleRefresh, // Sự kiện pull-to-refresh
        child: _errorMessage != null && _invoices.isEmpty
            ? _buildErrorView() // Hiển thị khi bị lỗi và không có dữ liệu
            : _invoices.isEmpty && !_isLoading
                ? _buildEmptyView() // Hiển thị khi không có hóa đơn nào
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _invoices.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Nếu cuộn đến phần tử cuối cùng và vẫn còn dữ liệu, hiển thị thanh tiến trình loading
                      if (index == _invoices.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: accentColor,
                              strokeWidth: 3,
                            ),
                          ),
                        );
                      }

                      final inv = _invoices[index];
                      return _buildInvoiceCard(inv, cardBgColor, accentColor, secondaryTextColor);
                    },
                  ),
      ),
    );
  }

  // Widget hiển thị thông tin từng hóa đơn
  Widget _buildInvoiceCard(
    Map<String, dynamic> inv,
    Color cardBg,
    Color accent,
    Color secText,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.05),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showInvoiceDetails(context, inv['id']),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Hiển thị ID hóa đơn
                    Text(
                      'Hóa đơn #${inv['id']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    // Số tiền thanh toán nổi bật với màu vàng nhạt
                    Text(
                      _formatCurrency(inv['final_amount']),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0xFF2E2E2D), height: 1),
                const SizedBox(height: 8),
                
                // Hiển thị chi nhánh & thời gian
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storefront_rounded, size: 14, color: secText),
                        const SizedBox(width: 6),
                        Text(
                          inv['branch_name'] ?? 'Không rõ chi nhánh',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                    Text(
                      _formatDateTime(inv['created_at']),
                      style: const TextStyle(color: Colors.white30, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Hiển thị Nhân viên & Điểm tích lũy
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 14, color: secText),
                        const SizedBox(width: 6),
                        Text(
                          'Thu ngân: ${inv['employee_name'] ?? 'Không rõ'}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    if (inv['points_earned'] != null && _parseNum(inv['points_earned']) > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3), width: 0.5),
                        ),
                        child: Text(
                          '+${inv['points_earned']} điểm',
                          style: const TextStyle(
                            color: Color(0xFF81C784),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget hiển thị khi danh sách trống
  Widget _buildEmptyView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_rounded, size: 64, color: Colors.white12),
              SizedBox(height: 16),
              Text(
                'Không có hóa đơn nào',
                style: TextStyle(color: Colors.white30, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'Kéo xuống để làm mới dữ liệu',
                style: TextStyle(color: Colors.white10, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget hiển thị khi xảy ra lỗi tải API
  Widget _buildErrorView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Đã xảy ra sự cố',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Lỗi không xác định',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white30, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFED876),
                    foregroundColor: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _fetchInvoices(isRefresh: true),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Hàm hiển thị Dialog chi tiết hóa đơn
  void _showInvoiceDetails(BuildContext context, dynamic invoiceId) {
    showDialog(
      context: context,
      builder: (context) {
        Map<String, dynamic>? invoiceDetail;
        bool isDetailLoading = true;
        String? detailError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Tải chi tiết hóa đơn từ API nếu chưa tải
            if (isDetailLoading && detailError == null && invoiceDetail == null) {
              Future.microtask(() async {
                try {
                  final token = await _storage.read(key: 'access_token');
                  final response = await http.get(
                    Uri.parse('$baseUrl/invoice/$invoiceId'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $token',
                      'ngrok-skip-browser-warning': 'true',
                    },
                  );
                  if (response.statusCode == 200 || response.statusCode == 201) {
                    final Map<String, dynamic> responseData = jsonDecode(response.body);
                    debugPrint("[CLIENT DEBUG] API Response Data: $responseData");
                    if (responseData['success'] == true && responseData['data'] != null) {
                      setDialogState(() {
                        invoiceDetail = Map<String, dynamic>.from(responseData['data']);
                        isDetailLoading = false;
                      });
                    } else {
                      throw Exception(responseData['message'] ?? 'Không lấy được chi tiết hóa đơn');
                    }
                  } else {
                    final body = jsonDecode(response.body);
                    throw Exception(body['message'] ?? 'Lỗi tải chi tiết hóa đơn');
                  }
                } catch (e) {
                  setDialogState(() {
                    detailError = e.toString().replaceAll('Exception: ', '');
                    isDetailLoading = false;
                  });
                }
              });
            }

            const accentColor = Color(0xFFFED876);
            const cardBgColor = Color(0xFF1E1E1E);

            return AlertDialog(
              backgroundColor: const Color(0xFF161615),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: accentColor.withValues(alpha: 0.15),
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
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: accentColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Chi tiết Hóa đơn #$invoiceId',
                        style: const TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: isDetailLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48.0),
                        child: Center(
                          child: CircularProgressIndicator(color: accentColor),
                        ),
                      )
                    : detailError != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Text(
                              'Lỗi: $detailError',
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : _buildReceiptLayout(invoiceDetail!, accentColor, cardBgColor),
              ),
              actions: isDetailLoading || detailError != null
                  ? []
                  : [
                      // Nút in hóa đơn
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: const Color(0xFF1E1E1E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.print_rounded, size: 20),
                            label: const Text(
                              'IN HÓA ĐƠN',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            onPressed: () {
                              // Giả lập gửi lệnh in tới máy in K80
                              Navigator.pop(context);
                              
                              // Show custom notification
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF6B5805),
                                  duration: const Duration(seconds: 3),
                                  content: Row(
                                    children: [
                                      const Icon(Icons.print_rounded, color: Colors.white),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Đang gửi lệnh in hóa đơn #$invoiceId tới máy in K80...',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              print("DEBUG PRINT: Gửi lệnh in hóa đơn #$invoiceId tới máy in K80 thành công.");
                            },
                          ),
                        ),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  // Widget hiển thị giao diện Bill Receipt
  Widget _buildReceiptLayout(Map<String, dynamic> inv, Color accent, Color cardBg) {
    final items = List<dynamic>.from(inv['details'] ?? inv['items'] ?? []);
    final createdAt = inv['created_at'];
    final branchName = inv['branch_name'] ?? 'Không rõ chi nhánh';
    final employeeName = inv['employee_name'] ?? 'Không rõ';
    final tableName = inv['table_number'] ?? 'Bàn mang đi';
    
    // Đọc các chi phí và chuyển đổi kiểu dữ liệu an toàn
    final subTotal = _parseNum(inv['sub_total']);
    final taxAmount = _parseNum(inv['tax_amount']);
    final serviceCharge = _parseNum(inv['service_charge']);
    final discountAmount = _parseNum(inv['discount_amount']) + _parseNum(inv['voucher_discount']);
    final finalAmount = _parseNum(inv['final_amount']);
    
    // Đọc thông tin thành viên (nếu có)
    final memberName = inv['member_name'];
    final memberPhone = inv['member_phone'];

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thông tin cơ bản
          Text(branchName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Thu ngân: $employeeName', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              Text('Vị trí: $tableName', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          Text('Thời gian: ${_formatDateTime(createdAt)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 12),
          
          // Nét đứt ngăn cách
          _buildDashedLine(),
          const SizedBox(height: 12),
          
          // Header các cột món ăn
          const Row(
            children: [
              Expanded(child: Text('TÊN MÓN', style: TextStyle(color: Color(0xFF7A704A), fontWeight: FontWeight.bold, fontSize: 11))),
              SizedBox(width: 8),
              Text('SL', style: TextStyle(color: Color(0xFF7A704A), fontWeight: FontWeight.bold, fontSize: 11)),
              SizedBox(width: 16),
              Text('ĐƠN GIÁ', style: TextStyle(color: Color(0xFF7A704A), fontWeight: FontWeight.bold, fontSize: 11)),
              SizedBox(width: 16),
              Text('T.TIỀN', style: TextStyle(color: Color(0xFF7A704A), fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          
          // Danh sách các món ăn
          ...items.map((item) {
            final name = item['product_name'] ?? '';
            final qty = _parseNum(item['quantity']);
            final price = _parseNum(item['unit_price']);
            final total = qty * price;
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('x$qty', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(width: 16),
                  Text(_formatRawNumber(price), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(width: 16),
                  Text(_formatRawNumber(total), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            );
          }),
          
          const SizedBox(height: 12),
          _buildDashedLine(),
          const SizedBox(height: 12),
          
          // Tổng hợp chi phí
          _buildReceiptRow('Tạm tính:', _formatCurrency(subTotal)),
          if (taxAmount > 0)
            _buildReceiptRow('Thuế VAT (10%):', _formatCurrency(taxAmount)),
          if (serviceCharge > 0)
            _buildReceiptRow('Phụ thu cuối tuần/lễ:', _formatCurrency(serviceCharge)),
          if (discountAmount > 0)
            _buildReceiptRow('Giảm giá:', '- ${_formatCurrency(discountAmount)}', valueColor: Colors.redAccent),
          
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TỔNG THANH TOÁN:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                _formatCurrency(finalAmount),
                style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          
          // Thông tin thành viên tích điểm (nếu có)
          if (memberName != null) ...[
            const SizedBox(height: 12),
            _buildDashedLine(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6B5805).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED876).withValues(alpha: 0.2), width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.stars_rounded, color: accent, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Thành viên: $memberName',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('SĐT: $memberPhone', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      if (inv['points_earned'] != null && _parseNum(inv['points_earned']) > 0)
                        Text(
                          'Tích lũy: +${inv['points_earned']} điểm',
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Định dạng số thông thường không có chữ 'đ'
  String _formatRawNumber(dynamic amount) {
    if (amount == null) return '0';
    final str = amount.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  // Hàm vẽ dòng thông số hóa đơn
  Widget _buildReceiptRow(String label, String value, {Color valueColor = Colors.white70}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white30, fontSize: 12)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 12)),
        ],
      ),
    );
  }

  // Đường kẻ nét đứt dạng Receipt
  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.white12),
              ),
            );
          }),
        );
      },
    );
  }
}
