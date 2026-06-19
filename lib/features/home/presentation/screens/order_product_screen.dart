import 'package:flutter/material.dart';
import 'package:staffapp/core/di/injection.dart';
import 'package:staffapp/core/widgets/dot_grid_background.dart';
import '../controllers/product_controller.dart';
import '../../data/models/product_model.dart';
import '../../data/models/category_model.dart';
import 'package:staffapp/core/widgets/custom_notification.dart';

class OrderProductScreen extends StatefulWidget {
  final String tableName;
  final List<Map<String, dynamic>> initialOrders;

  const OrderProductScreen({
    super.key,
    required this.tableName,
    required this.initialOrders,
  });

  @override
  State<OrderProductScreen> createState() => _OrderProductScreenState();
}

class _OrderProductScreenState extends State<OrderProductScreen> {
  late final ProductController _productController;
  String _selectedCategory = '';

  // Giỏ hàng hiện tại của bàn
  late List<Map<String, dynamic>> _cartOrders;



  @override
  void initState() {
    super.initState();
    _cartOrders = List.from(
      widget.initialOrders.map((item) => Map<String, dynamic>.from(item)),
    );

    _productController = sl<ProductController>();
    _productController.addListener(_onProductStateChanged);
    _productController.fetchCategoriesAndProducts();
  }

  @override
  void dispose() {
    _productController.removeListener(_onProductStateChanged);
    super.dispose();
  }

  void _onProductStateChanged() {
    if (mounted) {
      setState(() {
        if (_productController.errorMessage != null) {
          CustomNotification.show(
            context,
            message: _productController.errorMessage!,
            backgroundColor: Colors.redAccent,
            icon: Icons.error_outline,
          );
        }

        // Tự động chọn danh mục đầu tiên nếu danh mục hiện tại chưa được đặt hoặc không tồn tại trong danh sách mới
        if (_productController.categories.isNotEmpty) {
          final hasSelected = _productController.categories.any(
            (c) => c.name == _selectedCategory,
          );
          if (!hasSelected) {
            _selectedCategory = _productController.categories.first.name;
          }
        }
      });
    }
  }

  void _addProductToCart(ProductModel product) {
    setState(() {
      final productIntId = int.tryParse(product.id) ?? 0;
      final index = _cartOrders.indexWhere((item) => item['id'] == productIntId);
      if (index >= 0) {
        _cartOrders[index]['quantity']++;
      } else {
        _cartOrders.add({
          'id': productIntId, // Luôn lưu dạng int
          'name': product.name,
          'price': product.price,
          'quantity': 1,
        });
      }
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      _cartOrders[index]['quantity'] += delta;
      if (_cartOrders[index]['quantity'] <= 0) {
        _cartOrders.removeAt(index);
      }
    });
  }

  void _showQuantityInputDialog(int cartIndex) {
    final item = _cartOrders[cartIndex];
    final controller = TextEditingController(text: '${item['quantity']}');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF222221),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF333332), width: 1),
          ),
          title: Text(
            'Nhập số lượng cho\n${item['name']}',
            style: const TextStyle(
              color: Color(0xFFFED876),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF7A704A)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFFED876)),
              ),
            ),
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
                final intValue = int.tryParse(controller.text.trim());
                if (intValue != null) {
                  setState(() {
                    if (intValue <= 0) {
                      _cartOrders.removeAt(cartIndex);
                    } else {
                      _cartOrders[cartIndex]['quantity'] = intValue;
                    }
                  });
                }
                Navigator.pop(context);
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
  }

  int _calculateCartTotal() {
    return _cartOrders.fold(
      0,
      (total, item) =>
          total + (item['price'] as int) * (item['quantity'] as int),
    );
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('uống') ||
        lower.contains('drink') ||
        lower.contains('nước')) {
      return Icons.local_bar_rounded;
    }
    if (lower.contains('miệng') ||
        lower.contains('dessert') ||
        lower.contains('kem')) {
      return Icons.icecream_rounded;
    }
    return Icons.restaurant_menu_rounded;
  }

  IconData _getProductIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('cola') ||
        lower.contains('nước') ||
        lower.contains('suối')) {
      return Icons.local_drink_rounded;
    }
    if (lower.contains('bia') ||
        lower.contains('beer') ||
        lower.contains('heineken')) {
      return Icons.sports_bar_rounded;
    }
    if (lower.contains('kem') || lower.contains('ice')) {
      return Icons.icecream_rounded;
    }
    return Icons.flatware_rounded;
  }

  List<Color> _getProductGradient(String id) {
    final List<List<Color>> gradients = [
      [const Color(0xFFE52D27), const Color(0xFFB31217)],
      [const Color(0xFF2193b0), const Color(0xFF6dd5ed)],
      [const Color(0xFF11998e), const Color(0xFF38ef7d)],
      [const Color(0xFFFC466B), const Color(0xFF3F5EFB)],
      [const Color(0xFFF12711), const Color(0xFFF5AF19)],
    ];
    return gradients[id.hashCode % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    // Tìm danh mục đã chọn
    CategoryModel? selectedCategoryModel;
    if (_productController.categories.isNotEmpty) {
      try {
        selectedCategoryModel = _productController.categories.firstWhere(
          (c) => c.name == _selectedCategory,
        );
      } catch (_) {
        selectedCategoryModel = _productController.categories.first;
      }
    }

    final filteredProducts = _productController.products.where((p) {
      final prodCatId = p.categoryId.trim();
      final selectedCatId = selectedCategoryModel?.id.trim();
      return prodCatId ==
          selectedCatId; // Hiển thị tất cả kể cả các món bị off để nhân viên có thể bật/tắt
    }).toList();
    final totalCost = _calculateCartTotal();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0C),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF181817), Color(0xFF121211)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFFFED876).withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Nút back
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFFFED876),
                    size: 18,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),

                // Badge bàn
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6B5805).withValues(alpha: 0.4),
                        const Color(0xFF4A3E03).withValues(alpha: 0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFED876).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.table_restaurant_rounded,
                        color: Color(0xFFFED876),
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.tableName,
                        style: const TextStyle(
                          color: Color(0xFFFED876),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Tiêu đề
                const Text(
                  'Gọi món thêm',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const Spacer(),

                // Nút xóa giỏ hàng
                if (_cartOrders.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: TextButton.icon(
                      icon: const Icon(
                        Icons.delete_sweep_rounded,
                        color: Colors.redAccent,
                        size: 16,
                      ),
                      label: const Text(
                        'Xóa tất cả',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () {
                        setState(() => _cartOrders.clear());
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: DotGridBackground(
        backgroundColor: const Color(0xFF0D0D0C),
        dotColor: const Color(0xFF222221),
        dotRadius: 1.1,
        spacing: 20.0,
        child: _productController.isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFED876)),
                  SizedBox(height: 16),
                  Text(
                    'Đang tải danh sách món từ Server...',
                    style: TextStyle(color: Color(0xFF7A704A), fontSize: 14),
                  ),
                ],
              ),
            )
          : Row(
              children: [
                  // 1. Sidebar danh mục bên trái
                Container(
                  width: 130,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF181817), Color(0xFF131312)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border(
                      right: BorderSide(
                        color: const Color(0xFFFED876).withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                  ),
                  child: _productController.categories.isEmpty
                      ? const Center(
                          child: Text(
                            'Trống',
                            style: TextStyle(color: Color(0xFF555555)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: _productController.categories.length,
                          itemBuilder: (context, idx) {
                            final cat = _productController.categories[idx];
                            final isSelected = cat.name == _selectedCategory;
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _selectedCategory = cat.name,
                                ),
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    // Active indicator line
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 3,
                                      height: isSelected ? 56 : 0,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFED876),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF6B5805).withValues(alpha: 0.15)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getCategoryIcon(cat.name),
                                            color: isSelected
                                                ? const Color(0xFFFED876)
                                                : const Color(0xFF4A4A49),
                                            size: 24,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            cat.name,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? const Color(0xFFFED876)
                                                  : const Color(0xFF555554),
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // 2. Vùng hiển thị món ăn ở giữa
                Expanded(
                  child: filteredProducts.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.no_meals_rounded,
                                color: Color(0xFF2C2C2B),
                                size: 60,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Chưa có sản phẩm nào thuộc danh mục này',
                                style: TextStyle(color: Color(0xFF7A704A)),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(24),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisSpacing: 20,
                                crossAxisSpacing: 20,
                                childAspectRatio: 0.76,
                              ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, idx) {
                            final prod = filteredProducts[idx];
                            final cartIdx = _cartOrders.indexWhere(
                              (item) => item['id'] == prod.id,
                            );
                            final int quantityInCart = cartIdx >= 0
                                ? _cartOrders[cartIdx]['quantity'] as int
                                : 0;
                            final isOff = _productController.offProductIds.contains(prod.id);
                            final gradColors = isOff
                                ? [
                                    const Color(0xFF3A3A3A),
                                    const Color(0xFF242424),
                                  ]
                                : _getProductGradient(prod.id);

                            return Opacity(
                              opacity: isOff ? 0.5 : 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1D),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: quantityInCart > 0 && !isOff
                                        ? const Color(0xFFFED876)
                                        : const Color(0xFF2C2C2B),
                                    width: quantityInCart > 0 && !isOff
                                        ? 1.5
                                        : 1,
                                  ),
                                  boxShadow: [
                                    if (quantityInCart > 0 && !isOff)
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFED876,
                                        ).withValues(alpha: 0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          // Icon và Gradient nền món ăn
                                          Positioned.fill(
                                            child: Container(
                                              margin: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: gradColors,
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Icon(
                                                _getProductIcon(prod.name),
                                                color: Colors.white,
                                                size: 44,
                                              ),
                                            ),
                                          ),

                                          // Nhãn "Hết món" nếu bị off
                                          if (isOff)
                                            Center(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent
                                                      .withValues(alpha: 0.9),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'HẾT MÓN',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 12,
                                        right: 12,
                                        bottom: 12,
                                        top: 4,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            prod.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${prod.price.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                                            style: const TextStyle(
                                              color: Color(0xFFFED876),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            height: 38,
                                            child: isOff
                                                ? Container(
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF151514,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      border: Border.all(
                                                        color: const Color(
                                                          0xFF2C2C2B,
                                                        ),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Tạm ngưng',
                                                      style: TextStyle(
                                                        color: Colors.white38,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  )
                                                : (quantityInCart > 0
                                                      ? Container(
                                                          decoration: BoxDecoration(
                                                            color: const Color(
                                                              0xFF232322,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  20,
                                                                ),
                                                            border: Border.all(
                                                              color:
                                                                  const Color(
                                                                    0xFFFED876,
                                                                  ).withValues(
                                                                    alpha: 0.3,
                                                                  ),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              GestureDetector(
                                                                onTap: () =>
                                                                    _updateQuantity(
                                                                      cartIdx,
                                                                      -1,
                                                                    ),
                                                                behavior:
                                                                    HitTestBehavior
                                                                        .opaque,
                                                                child: Container(
                                                                  width: 34,
                                                                  height: 34,
                                                                  margin:
                                                                      const EdgeInsets.all(
                                                                        1,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(
                                                                      0xFF2C2C2B,
                                                                    ),
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    border: Border.all(
                                                                      color:
                                                                          const Color(
                                                                            0xFFFED876,
                                                                          ).withValues(
                                                                            alpha:
                                                                                0.1,
                                                                          ),
                                                                      width: 1,
                                                                    ),
                                                                  ),
                                                                  child: const Icon(
                                                                    Icons
                                                                        .remove_rounded,
                                                                    color: Color(
                                                                      0xFFFED876,
                                                                    ),
                                                                    size: 16,
                                                                  ),
                                                                ),
                                                              ),
                                                              GestureDetector(
                                                                onTap: () =>
                                                                    _showQuantityInputDialog(
                                                                      cartIdx,
                                                                    ),
                                                                behavior:
                                                                    HitTestBehavior
                                                                        .opaque,
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            12,
                                                                        vertical:
                                                                            8,
                                                                      ),
                                                                  child: Text(
                                                                    '$quantityInCart',
                                                                    style: const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          14,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              GestureDetector(
                                                                onTap: () =>
                                                                    _updateQuantity(
                                                                      cartIdx,
                                                                      1,
                                                                    ),
                                                                behavior:
                                                                    HitTestBehavior
                                                                        .opaque,
                                                                child: Container(
                                                                  width: 34,
                                                                  height: 34,
                                                                  margin:
                                                                      const EdgeInsets.all(
                                                                        1,
                                                                      ),
                                                                  decoration: const BoxDecoration(
                                                                    color: Color(
                                                                      0xFFFED876,
                                                                    ),
                                                                    shape: BoxShape
                                                                        .circle,
                                                                  ),
                                                                  child: const Icon(
                                                                    Icons
                                                                        .add_rounded,
                                                                    color: Color(
                                                                      0xFF1E1E1D,
                                                                    ),
                                                                    size: 16,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      : ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                const Color(
                                                                  0xFF151514,
                                                                ),
                                                            foregroundColor:
                                                                const Color(
                                                                  0xFFFED876,
                                                                ),
                                                            elevation: 0,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                              side: const BorderSide(
                                                                color: Color(
                                                                  0xFF2C2C2B,
                                                                ),
                                                                width: 1,
                                                              ),
                                                            ),
                                                          ),
                                                          onPressed: () =>
                                                              _addProductToCart(
                                                                prod,
                                                              ),
                                                          child: const Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .add_rounded,
                                                                size: 16,
                                                              ),
                                                              SizedBox(
                                                                width: 4,
                                                              ),
                                                              Text(
                                                                'Thêm',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // 3. Panel giỏ hàng bên phải
                Container(
                  width: 320,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF181817), Color(0xFF131312)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border(
                      left: BorderSide(
                        color: const Color(0xFFFED876).withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header giỏ hàng
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: const Color(0xFFFED876).withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6B5805).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFFFED876),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Món đã chọn',
                              style: TextStyle(
                                color: Color(0xFFFED876),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const Spacer(),
                            if (_cartOrders.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFED876),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_cartOrders.length}',
                                  style: const TextStyle(
                                    color: Color(0xFF1E1E1D),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _cartOrders.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_rounded,
                                      color: Color(0xFF2C2C2B),
                                      size: 60,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Giỏ hàng đang trống',
                                      style: TextStyle(
                                        color: Color(0xFF7A704A),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Hãy chọn món từ danh sách bên trái',
                                      style: TextStyle(
                                        color: Color(0xFF444443),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _cartOrders.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, idx) {
                                  final item = _cartOrders[idx];
                                  final itemTotal =
                                      (item['price'] as int) *
                                      (item['quantity'] as int);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF1E1C10), Color(0xFF1A1A19)],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFFED876).withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '${itemTotal.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                                                style: const TextStyle(
                                                  color: Color(0xFFFED876),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E1E1D),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFF232322),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () =>
                                                    _updateQuantity(idx, -1),
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                child: Container(
                                                  width: 28,
                                                  height: 28,
                                                  margin: const EdgeInsets.all(
                                                    2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF2C2C2B,
                                                    ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFFFED876,
                                                      ).withValues(alpha: 0.1),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.remove_rounded,
                                                    color: Color(0xFFFED876),
                                                    size: 14,
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () =>
                                                    _showQuantityInputDialog(
                                                      idx,
                                                    ),
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  child: Text(
                                                    '${item['quantity']}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () =>
                                                    _updateQuantity(idx, 1),
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                child: Container(
                                                  width: 28,
                                                  height: 28,
                                                  margin: const EdgeInsets.all(
                                                    2,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Color(
                                                          0xFFFED876,
                                                        ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.add_rounded,
                                                    color: Color(0xFF1E1E1D),
                                                    size: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      // Footer: tổng tiền + nút xác nhận
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1C1A0C), Color(0xFF161513)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          border: Border(
                            top: BorderSide(
                              color: const Color(0xFFFED876).withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tổng gọi thêm',
                                      style: TextStyle(
                                        color: Color(0xFF7A704A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${totalCost.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} đ',
                                      style: const TextStyle(
                                        color: Color(0xFFFED876),
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${_cartOrders.length} loại món',
                                  style: const TextStyle(
                                    color: Color(0xFF555554),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 50,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _cartOrders.isEmpty
                                      ? const Color(0xFF2A2A29)
                                      : const Color(0xFFFED876),
                                  foregroundColor: _cartOrders.isEmpty
                                      ? const Color(0xFF555555)
                                      : const Color(0xFF1E1E1E),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: _cartOrders.isEmpty ? 0 : 4,
                                  shadowColor: const Color(0xFFFED876).withValues(alpha: 0.3),
                                ),
                                onPressed: _cartOrders.isEmpty
                                    ? null
                                    : () {
                                        print(
                                          "DEBUG GIỎ HÀNG (MÓN ĐÃ CHỌ N): $_cartOrders",
                                        );
                                        Navigator.pop(context, _cartOrders);
                                      },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _cartOrders.isEmpty
                                          ? 'Chưa chọn món nào'
                                          : 'XÁC NHẬN GỌI MÓN',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
