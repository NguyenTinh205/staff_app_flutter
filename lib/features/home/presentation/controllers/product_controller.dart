import 'package:flutter/material.dart';
import '../../domain/repositories/product_repository.dart';
import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/payment_method_model.dart';
import '../../data/models/checkout_response_model.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/member_model.dart';

class ProductController extends ChangeNotifier {
  final ProductRepository productRepository;

  ProductController({required this.productRepository});

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<CategoryModel> _categories = [];
  List<CategoryModel> get categories => _categories;

  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;

  List<PaymentMethodModel> _paymentMethods = [];
  List<PaymentMethodModel> get paymentMethods => _paymentMethods;

  CheckoutResponseModel? _checkoutData;
  CheckoutResponseModel? get checkoutData => _checkoutData;

  // Set lưu trữ danh sách ID món ăn bị off tạm thời
  final Set<String> _offProductIds = {};
  Set<String> get offProductIds => _offProductIds;

  // Set lưu trữ các bàn đã thanh toán thành công qua socket
  final Set<String> _paidTables = {};
  Set<String> get paidTables => _paidTables;

  // Map lưu trữ thông tin hóa đơn đã thanh toán thành công của từng bàn
  final Map<String, InvoiceModel> _paidInvoices = {};
  Map<String, InvoiceModel> get paidInvoices => _paidInvoices;

  void markTableAsPaid(String tableName, [InvoiceModel? invoice]) {
    final key = tableName.trim().toLowerCase();
    _paidTables.add(key);
    if (invoice != null) {
      _paidInvoices[key] = invoice;
    }
    notifyListeners();
  }

  void clearTablePaidStatus(String tableName) {
    final key = tableName.trim().toLowerCase();
    _paidTables.remove(key);
    _paidInvoices.remove(key);
    notifyListeners();
  }

  void toggleProductAvailability(String id) {
    if (_offProductIds.contains(id)) {
      _offProductIds.remove(id);
    } else {
      _offProductIds.add(id);
    }
    notifyListeners();
  }

  void clearCheckoutData() {
    _checkoutData = null;
    notifyListeners();
  }

  Future<void> fetchCategoriesAndProducts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetchedCategories = await productRepository.getAllCategories();
      final fetchedProducts = await productRepository.getAllProducts();

      debugPrint("DEBUG: Hạng mục tải về từ API: ${fetchedCategories.length}");
      for (var c in fetchedCategories) {
        debugPrint(
          "DEBUG: Category: id='${c.id}', name='${c.name}', isActive=${c.isActive}",
        );
      }

      debugPrint("DEBUG: Sản phẩm tải về từ API: ${fetchedProducts.length}");
      for (var p in fetchedProducts) {
        debugPrint(
          "DEBUG: Product: id='${p.id}', name='${p.name}', categoryId='${p.categoryId}', price=${p.price}, isAvailable=${p.isAvailable}",
        );
      }

      _categories = fetchedCategories;
      _products = fetchedProducts;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPaymentMethods() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _paymentMethods = await productRepository.getPaymentMethods();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CheckoutResponseModel?> createCheckoutLink({
    required String invoiceId,
    required String paymentMethodId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await productRepository.createCheckoutLink(
        invoiceId: invoiceId,
        paymentMethodId: paymentMethodId,
      );
      _checkoutData = data;
      _isLoading = false;
      notifyListeners();
      return data;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<InvoiceModel?> createDraftInvoice({
    int? memberId,
    required String tableNumber,
    required int taxAmount,
    required int serviceCharge,
    required int pointsMultiplier,
    required List<Map<String, dynamic>> items,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final invoice = await productRepository.createDraftInvoice(
        memberId: memberId,
        tableNumber: tableNumber,
        taxAmount: taxAmount,
        serviceCharge: serviceCharge,
        pointsMultiplier: pointsMultiplier,
        items: items,
      );
      _isLoading = false;
      notifyListeners();
      return invoice;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<MemberModel?> searchMemberByPhone(String phone) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final member = await productRepository.searchMemberByPhone(phone);
      _isLoading = false;
      notifyListeners();
      return member;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<InvoiceModel?> linkMember({
    required String invoiceId,
    required int memberId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final invoice = await productRepository.linkMember(
        invoiceId: invoiceId,
        memberId: memberId,
      );
      _isLoading = false;
      notifyListeners();
      return invoice;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> cancelDraftInvoice(String invoiceId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await productRepository.cancelDraftInvoice(invoiceId);
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
