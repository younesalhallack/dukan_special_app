import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../settings/providers/settings_providers.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(appDatabaseProvider));
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(appDatabaseProvider));
});

/// Search text and category chosen on the products screen.
class ProductFilter {
  const ProductFilter({this.query = '', this.categoryId});

  final String query;

  /// Null means "all categories".
  final int? categoryId;
}

class ProductFilterNotifier extends Notifier<ProductFilter> {
  @override
  ProductFilter build() => const ProductFilter();

  void setQuery(String query) {
    state = ProductFilter(query: query, categoryId: state.categoryId);
  }

  void setCategory(int? categoryId) {
    state = ProductFilter(query: state.query, categoryId: categoryId);
  }
}

final productFilterProvider =
    NotifierProvider<ProductFilterNotifier, ProductFilter>(
  ProductFilterNotifier.new,
);

final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).list();
});

final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) {
  final filter = ref.watch(productFilterProvider);
  return ref.watch(productRepositoryProvider).list(
        query: filter.query,
        categoryId: filter.categoryId,
      );
});

final lowStockProvider = FutureProvider.autoDispose<List<Product>>((ref) {
  final threshold =
      ref.watch(settingsProvider).value?.defaultLowStockThreshold ?? 5;
  return ref.watch(productRepositoryProvider).lowStock(threshold.toDouble());
});

extension InventoryRefresh on WidgetRef {
  /// Reloads every inventory list after a change.
  void refreshInventory() {
    invalidate(productsProvider);
    invalidate(lowStockProvider);
    invalidate(categoriesProvider);
  }
}
