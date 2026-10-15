import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../data/models/product.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../logic/cart_calculator.dart';

/// The cart being built on the POS screen.
class CartState {
  const CartState({
    this.lines = const <CartLine>[],
    this.currency,
    this.discount = 0,
  });

  final List<CartLine> lines;

  /// Invoice currency; null means "the base currency from the settings".
  final Currency? currency;

  /// Invoice-level discount in the invoice currency.
  final int discount;
}

double _roundQuantity(double value) => double.parse(value.toStringAsFixed(3));

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void addProduct(Product product, {double quantity = 1}) {
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.productId == product.id);
    if (index >= 0) {
      lines[index] = lines[index].copyWith(
        quantity: _roundQuantity(lines[index].quantity + quantity),
      );
    } else {
      lines.add(CartLine(
        productId: product.id,
        name: product.name,
        salePrice: product.salePrice,
        saleCurrency: product.saleCurrency,
        costPrice: product.costPrice,
        costCurrency: product.costCurrency,
        quantity: _roundQuantity(quantity),
        stockQuantity: product.quantity,
      ));
    }
    state = CartState(
      lines: lines,
      currency: state.currency,
      discount: state.discount,
    );
  }

  /// Sets the quantity of a line. A quantity of zero or less removes it.
  void setQuantity(int productId, double quantity) {
    if (quantity <= 0) {
      remove(productId);
      return;
    }
    state = CartState(
      lines: [
        for (final line in state.lines)
          line.productId == productId
              ? line.copyWith(quantity: _roundQuantity(quantity))
              : line,
      ],
      currency: state.currency,
      discount: state.discount,
    );
  }

  void remove(int productId) {
    state = CartState(
      lines: [
        for (final line in state.lines)
          if (line.productId != productId) line,
      ],
      currency: state.currency,
      discount: state.discount,
    );
  }

  /// Changes the invoice currency. The discount is cleared because its
  /// amount was typed in the previous currency.
  void setCurrency(Currency currency) {
    if (state.currency == currency) return;
    state = CartState(lines: state.lines, currency: currency, discount: 0);
  }

  void setDiscount(int discount) {
    state = CartState(
      lines: state.lines,
      currency: state.currency,
      discount: discount < 0 ? 0 : discount,
    );
  }

  void clear() => state = const CartState();
}

final cartProvider =
    NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

/// The cart priced with the CURRENT settings. Null until the app is set up.
/// It is recomputed whenever the cart or the exchange rate changes.
final cartTotalsProvider = Provider<CartTotals?>((ref) {
  final cart = ref.watch(cartProvider);
  final settings = ref.watch(settingsProvider).value;
  if (settings == null || !settings.isConfigured) return null;
  return CartCalculator.calculate(
    lines: cart.lines,
    currency: cart.currency ?? settings.baseCurrency!,
    rate: settings.rate,
    sypStep: settings.sypRoundingStep,
    discount: cart.discount,
  );
});

/// Product search for the POS screen (limited to 30 results).
final posSearchProvider =
    FutureProvider.autoDispose.family<List<Product>, String>((ref, query) {
  return ref.watch(productRepositoryProvider).list(query: query, limit: 30);
});
