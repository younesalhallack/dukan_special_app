import 'package:sqflite/sqflite.dart';

import '../../core/currency/currency.dart';
import '../../core/database/schema.dart';
import '../models/customer_balance.dart';

/// The one place where customer balances are computed:
///
///   balance = sum(total - paid) of completed credit invoices
///           - sum(applied_amount) of payments that are not voided
///
/// per customer and per currency.
abstract final class BalanceQueries {
  static Future<Map<int, CustomerBalance>> forAll(
    DatabaseExecutor executor, {
    int? customerId,
  }) async {
    final filter = customerId == null ? '' : ' AND customer_id = ?';
    final args = customerId == null ? <Object?>[] : <Object?>[customerId];

    final invoices = await executor.rawQuery(
      'SELECT customer_id, currency, SUM(total_amount - paid_amount) AS amount '
      'FROM ${Tables.transactions} '
      "WHERE payment_type = 'credit' AND status = 'completed' "
      'AND customer_id IS NOT NULL$filter '
      'GROUP BY customer_id, currency',
      args,
    );
    final payments = await executor.rawQuery(
      'SELECT customer_id, applied_currency AS currency, '
      'SUM(applied_amount) AS amount '
      'FROM ${Tables.customerPayments} '
      'WHERE is_voided = 0$filter '
      'GROUP BY customer_id, applied_currency',
      args,
    );

    final totals = <int, Map<Currency, int>>{};
    void add(List<Map<String, Object?>> rows, int sign) {
      for (final row in rows) {
        final id = row['customer_id'] as int;
        final currency = Currency.fromCode(row['currency'] as String);
        final amount = (row['amount'] as num).toInt() * sign;
        final byCurrency = totals.putIfAbsent(id, () => <Currency, int>{});
        byCurrency[currency] = (byCurrency[currency] ?? 0) + amount;
      }
    }

    add(invoices, 1);
    add(payments, -1);
    return {
      for (final entry in totals.entries) entry.key: CustomerBalance(entry.value),
    };
  }

  static Future<CustomerBalance> forCustomer(
    DatabaseExecutor executor,
    int customerId,
  ) async {
    final all = await forAll(executor, customerId: customerId);
    return all[customerId] ?? CustomerBalance.zero;
  }
}
