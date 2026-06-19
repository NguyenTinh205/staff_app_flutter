import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/payment_method_model.dart';
import '../../data/models/checkout_response_model.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/member_model.dart';

abstract class ProductRepository {
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
