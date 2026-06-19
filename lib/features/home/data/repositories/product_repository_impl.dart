import '../../domain/repositories/product_repository.dart';
import '../datasources/product_remote_data_source.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/payment_method_model.dart';
import '../models/checkout_response_model.dart';
import '../models/invoice_model.dart';
import '../models/member_model.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remoteDataSource;

  ProductRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<CategoryModel>> getAllCategories() async {
    return await remoteDataSource.getAllCategories();
  }

  @override
  Future<List<ProductModel>> getAllProducts() async {
    return await remoteDataSource.getAllProducts();
  }

  @override
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    return await remoteDataSource.getPaymentMethods();
  }

  @override
  Future<CheckoutResponseModel> createCheckoutLink({
    required String invoiceId,
    required String paymentMethodId,
  }) async {
    return await remoteDataSource.createCheckoutLink(
      invoiceId: invoiceId,
      paymentMethodId: paymentMethodId,
    );
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
    return await remoteDataSource.createDraftInvoice(
      memberId: memberId,
      tableNumber: tableNumber,
      taxAmount: taxAmount,
      serviceCharge: serviceCharge,
      pointsMultiplier: pointsMultiplier,
      items: items,
    );
  }

  @override
  Future<MemberModel> searchMemberByPhone(String phone) async {
    return await remoteDataSource.searchMemberByPhone(phone);
  }

  @override
  Future<InvoiceModel> linkMember({
    required String invoiceId,
    required int memberId,
  }) async {
    return await remoteDataSource.linkMember(
      invoiceId: invoiceId,
      memberId: memberId,
    );
  }
}
