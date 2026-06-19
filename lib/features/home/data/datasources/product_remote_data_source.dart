import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/payment_method_model.dart';
import '../models/checkout_response_model.dart';
import '../models/invoice_model.dart';
import '../models/member_model.dart';

abstract class ProductRemoteDataSource {
  Future<List<CategoryModel>> getAllCategories();
  Future<List<ProductModel>> getAllProducts();
  Future<List<PaymentMethodModel>> getPaymentMethods();
  Future<CheckoutResponseModel> createCheckoutLink({
    required String invoiceId,
    required String paymentMethodId,
  });
  Future<InvoiceModel> createDraftInvoice({
    int? memberId,
    required String tableNumber,
    required int taxAmount,
    required int serviceCharge,
    required int pointsMultiplier,
    required List<Map<String, dynamic>> items,
  });
  Future<MemberModel> searchMemberByPhone(String phone);
  Future<InvoiceModel> linkMember({
    required String invoiceId,
    required int memberId,
  });
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final http.Client client;
  final FlutterSecureStorage storage;
  final String baseUrl =
      'https://nonoily-overinfluential-deegan.ngrok-free.dev/api';

  ProductRemoteDataSourceImpl({required this.client, required this.storage});

  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
    };
  }

  @override
  Future<List<CategoryModel>> getAllCategories() async {
    final headers = await _getHeaders();
    final response = await client.get(
      Uri.parse('$baseUrl/employee/categories'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final dynamic body = jsonDecode(response.body);
      final List<dynamic> jsonList = body['data'] as List;
      return jsonList.map((json) => CategoryModel.fromJson(json)).toList();
    } else {
      throw Exception('Lấy danh sách danh mục thất bại');
    }
  }

  @override
  Future<List<ProductModel>> getAllProducts() async {
    final headers = await _getHeaders();
    final response = await client.get(
      Uri.parse('$baseUrl/employee/products?limit=1000'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final dynamic body = jsonDecode(response.body);
      final dynamic data = body['data'];
      List<dynamic> jsonList = [];
      if (data is List) {
        jsonList = data;
      } else if (data is Map && data['products'] is List) {
        jsonList = data['products'];
      }
      return jsonList.map((json) => ProductModel.fromJson(json)).toList();
    } else {
      throw Exception('Lấy danh sách sản phẩm thất bại');
    }
  }

  @override
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    final headers = await _getHeaders();
    final response = await client.get(
      Uri.parse('$baseUrl/paymentMethod'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final dynamic body = jsonDecode(response.body);
      final List<dynamic> jsonList = body['data'] as List;
      return jsonList.map((json) => PaymentMethodModel.fromJson(json)).toList();
    } else {
      throw Exception('Lấy danh sách phương thức thanh toán thất bại');
    }
  }

  @override
  Future<CheckoutResponseModel> createCheckoutLink({
    required String invoiceId,
    required String paymentMethodId,
  }) async {
    final headers = await _getHeaders();
    final response = await client.post(
      Uri.parse('$baseUrl/invoice/$invoiceId/checkout'),
      headers: headers,
      body: jsonEncode({'payment_method_id': paymentMethodId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print("DEBUG: API Create Checkout Link Response Body = ${response.body}");
      final Map<String, dynamic> body = jsonDecode(response.body);
      return CheckoutResponseModel.fromJson(body['data']);
    } else {
      try {
        final dynamic body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Tạo link thanh toán thất bại');
      } catch (e) {
        if (e is FormatException) {
          throw Exception(
            'Máy chủ gặp sự cố (Lỗi ${response.statusCode}) khi kết nối cổng thanh toán PayOS. Vui lòng kiểm tra cấu hình .env và log của Backend.',
          );
        }
        rethrow;
      }
    }
  }

  @override
  Future<InvoiceModel> createDraftInvoice({
    int? memberId,
    required String tableNumber,
    required int taxAmount,
    required int serviceCharge,
    required int pointsMultiplier,
    required List<Map<String, dynamic>> items,
  }) async {
    final headers = await _getHeaders();
    final response = await client.post(
      Uri.parse('$baseUrl/invoice/draft'),
      headers: headers,
      body: jsonEncode({
        if (memberId != null) 'member_id': memberId,
        'table_number': tableNumber,
        'tax_amount': taxAmount,
        'service_charge': serviceCharge,
        'points_multiplier': pointsMultiplier,
        'items': items,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print("DEBUG: API Create Draft Response Body = ${response.body}");
      final Map<String, dynamic> body = jsonDecode(response.body);
      return InvoiceModel.fromJson(body['data']);
    } else {
      try {
        final dynamic body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Tạo hóa đơn nháp thất bại');
      } catch (e) {
        if (e is FormatException) {
          throw Exception(
            'Máy chủ gặp sự cố (Lỗi ${response.statusCode}) khi tạo hóa đơn nháp. Vui lòng kiểm tra cấu hình .env và log của Backend.',
          );
        }
        rethrow;
      }
    }
  }

  @override
  Future<MemberModel> searchMemberByPhone(String phone) async {
    final headers = await _getHeaders();

    final response = await client.get(
      Uri.parse('$baseUrl/member/phone?phone=$phone'),
      headers: headers,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print("DEBUG: searchMemberByPhone Response = ${response.body}");
      final Map<String, dynamic> body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        return MemberModel.fromJson(body['data']);
      } else {
        throw Exception(body['message'] ?? 'Không tìm thấy thành viên');
      }
    } else {
      try {
        final dynamic body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Tìm kiếm thành viên thất bại');
      } catch (e) {
        throw Exception(e);
      }
    }
  }

  @override
  Future<InvoiceModel> linkMember({
    required String invoiceId,
    required int memberId,
  }) async {
    final headers = await _getHeaders();
    final response = await client.patch(
      Uri.parse('$baseUrl/invoice/$invoiceId/link-member'),
      headers: headers,
      body: jsonEncode({
        'member_id': memberId,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      print("DEBUG: API Link Member Response Body = ${response.body}");
      final Map<String, dynamic> body = jsonDecode(response.body);
      return InvoiceModel.fromJson(body['data']);
    } else {
      try {
        final dynamic body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Liên kết thành viên thất bại');
      } catch (e) {
        if (e is FormatException) {
          throw Exception(
            'Máy chủ gặp sự cố (Lỗi ${response.statusCode}) khi liên kết thành viên. Vui lòng kiểm tra cấu hình .env và log của Backend.',
          );
        }
        rethrow;
      }
    }
  }
}
