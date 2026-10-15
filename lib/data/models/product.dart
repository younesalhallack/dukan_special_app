import '../../core/currency/currency.dart';

/// A product (row of the `products` table, plus the category name).
class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.barcode,
    required this.costPrice,
    required this.costCurrency,
    required this.salePrice,
    required this.saleCurrency,
    required this.quantity,
    required this.lowStockThreshold,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int? categoryId;
  final String? categoryName;
  final String name;
  final String? barcode;

  /// Minor units of [costCurrency].
  final int costPrice;
  final Currency costCurrency;

  /// Minor units of [saleCurrency].
  final int salePrice;
  final Currency saleCurrency;

  final double quantity;

  /// Null means "use the default threshold from the settings".
  final double? lowStockThreshold;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  /// True when the stock is at or below the alert level.
  bool isLowStock(double defaultThreshold) =>
      quantity <= (lowStockThreshold ?? defaultThreshold);

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as int,
      categoryId: map['category_id'] as int?,
      categoryName: map['category_name'] as String?,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      costPrice: map['cost_price'] as int,
      costCurrency: Currency.fromCode(map['cost_currency'] as String),
      salePrice: map['sale_price'] as int,
      saleCurrency: Currency.fromCode(map['sale_currency'] as String),
      quantity: (map['quantity'] as num).toDouble(),
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toDouble(),
      isActive: (map['is_active'] as int) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}

/// Editable fields of a product, used to create or update one.
/// The quantity is NOT editable after creation: use stock adjustments.
class ProductInput {
  const ProductInput({
    required this.name,
    required this.salePrice,
    this.categoryId,
    this.barcode,
    this.costPrice = 0,
    this.costCurrency = Currency.usd,
    this.saleCurrency = Currency.usd,
    this.lowStockThreshold,
    this.initialQuantity = 0,
  });

  final String name;
  final int? categoryId;
  final String? barcode;
  final int costPrice;
  final Currency costCurrency;
  final int salePrice;
  final Currency saleCurrency;
  final double? lowStockThreshold;

  /// Only used by `create`.
  final double initialQuantity;
}
