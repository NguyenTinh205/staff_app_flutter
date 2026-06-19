class ProductModel {
  final String id;
  final String name;
  final int price;
  final String categoryId;
  final String? description;
  final bool isAvailable;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    this.description,
    required this.isAvailable,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    String catId = '';
    if (json['category_id'] != null) {
      catId = json['category_id'].toString();
    } else if (json['category'] is Map) {
      catId = json['category']['id']?.toString() ?? json['category']['_id']?.toString() ?? '';
    }else if(json['category'] is String){
      catId = json['category'];
    }

    return ProductModel(
      id: json['id']?.toString()??json['_id']?.toString()??'',
      name: json['name'] ?? '',
      price: json['base_price'] is num 
          ? (json['base_price'] as num).toInt() 
          : (json['base_price'] != null ? int.tryParse(json['base_price'].toString()) ?? 0 : 0),
      categoryId: catId,
      description: json['description'],
      isAvailable: json['is_active'] ?? json['isAvailable']??(json['status']=='available')??true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': categoryId,
      'description': description,
      'isAvailable': isAvailable,
    };
  }
}
