import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/currency.dart';
import '../../core/currency/money.dart';
import '../../l10n/l10n.dart';
import '../backup/widgets/backup_reminder_card.dart';
import '../customers/providers/customers_providers.dart';
import '../customers/screens/customers_screen.dart';
import '../inventory/providers/inventory_providers.dart';
import '../purchases/screens/purchases_history_screen.dart';
import '../suppliers/providers/suppliers_providers.dart';
import '../suppliers/screens/suppliers_screen.dart';
import '../inventory/screens/categories_screen.dart';
import '../inventory/screens/low_stock_screen.dart';
import '../inventory/screens/products_screen.dart';
import '../pos/screens/pos_screen.dart';
import '../pos/screens/sales_history_screen.dart';
import '../settings/providers/settings_providers.dart';
import '../settings/screens/settings_screen.dart';

/// Temporary home screen: entry points to the screens built so far.
/// It will be replaced by the real navigation in a later step.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) return const SizedBox.shrink();
    final lowStockCount = ref.watch(lowStockProvider).value?.length ?? 0;
    final debtors = ref.watch(debtTotalsProvider).value?.customersWithDebt ?? 0;
    final owedSuppliers = ref.watch(payableTotalsProvider).value?.suppliersOwed ?? 0;

    const usdMinor = 1000; // 10.00 USD
    final syp = Money.salePriceIn(
      amountMinor: usdMinor,
      from: Currency.usd,
      to: Currency.syp,
      rate: settings.rate,
      sypStep: settings.sypRoundingStep,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settingsTitle,
            onPressed: () => _open(context, const SettingsScreen()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const BackupReminderCard(),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.point_of_sale),
              title: Text(l10n.pos),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, const PosScreen()),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l10n.salesHistory),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, const SalesHistoryScreen()),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(l10n.customers),
              trailing: debtors > 0
                  ? Badge(label: Text('$debtors'))
                  : const Icon(Icons.chevron_right),
              onTap: () => _open(context, const CustomersScreen()),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.shopping_bag_outlined),
              title: Text(l10n.purchases),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, const PurchasesHistoryScreen()),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text(l10n.suppliers),
              trailing: owedSuppliers > 0
                  ? Badge(label: Text('$owedSuppliers'))
                  : const Icon(Icons.chevron_right),
              onTap: () => _open(context, const SuppliersScreen()),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(l10n.products),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, const ProductsScreen()),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.category_outlined),
              title: Text(l10n.categories),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, const CategoriesScreen()),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.warning_amber_rounded,
                color: lowStockCount > 0
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
              title: Text(l10n.lowStock),
              trailing: lowStockCount > 0
                  ? Badge(label: Text('$lowStockCount'))
                  : const Icon(Icons.chevron_right),
              onTap: () => _open(context, const LowStockScreen()),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    l10n.homeDemoTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    Money.format(
                      usdMinor,
                      Currency.usd,
                      digits: settings.digitStyle,
                    ),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Text('='),
                  Text(
                    Money.format(
                      syp,
                      Currency.syp,
                      digits: settings.digitStyle,
                    ),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
