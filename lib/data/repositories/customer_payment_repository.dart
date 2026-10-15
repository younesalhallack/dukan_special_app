import '../../core/currency/currency.dart';
import '../../core/currency/payment_math.dart';
import '../../core/database/app_database.dart';
import '../../core/database/schema.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/customer_payment.dart';
import 'balance_queries.dart';

/// Records and cancels debt payments.
class CustomerPaymentRepository {
  CustomerPaymentRepository(this._appDb);

  final AppDatabase _appDb;

  /// Records a payment of [amount] ([currency]) against the customer's debt
  /// in [appliedCurrency], converted at [rate] (SYP per 1 USD). Everything is
  /// checked against the balance inside one transaction. Returns the id.
  Future<int> addPayment({
    required int customerId,
    required int amount,
    required Currency currency,
    required Currency appliedCurrency,
    required double rate,
    String? note,
  }) async {
    if (amount <= 0 || !rate.isFinite || rate <= 0) {
      throw const AppException(AppError.invalidAmount);
    }
    final cleanNote = (note == null || note.trim().isEmpty) ? null : note.trim();
    return _appDb.runInTransaction((txn) async {
      final customer = await txn.query(
        Tables.customers,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (customer.isEmpty) throw const AppException(AppError.notFound);

      final balance =
          (await BalanceQueries.forCustomer(txn, customerId)).of(appliedCurrency);
      if (balance <= 0) throw const AppException(AppError.noDebt);

      final applied = PaymentMath.resolveApplied(
        amount: amount,
        payCurrency: currency,
        appliedCurrency: appliedCurrency,
        rate: rate,
        balance: balance,
      );

      return txn.insert(Tables.customerPayments, {
        'customer_id': customerId,
        'amount': amount,
        'currency': currency.code,
        'exchange_rate': rate,
        'applied_amount': applied,
        'applied_currency': appliedCurrency.code,
        'note': cleanNote,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'is_voided': 0,
      });
    });
  }

  /// Cancels a payment: it stays in the ledger but no longer counts.
  Future<void> voidPayment(int paymentId) async {
    await _appDb.runInTransaction((txn) async {
      final rows = await txn.query(
        Tables.customerPayments,
        columns: ['is_voided'],
        where: 'id = ?',
        whereArgs: [paymentId],
        limit: 1,
      );
      if (rows.isEmpty) throw const AppException(AppError.notFound);
      if ((rows.first['is_voided'] as int) == 1) {
        throw const AppException(AppError.alreadyVoided);
      }
      await txn.update(
        Tables.customerPayments,
        {'is_voided': 1},
        where: 'id = ?',
        whereArgs: [paymentId],
      );
    });
  }

  /// Payments of a customer (including cancelled ones), newest first.
  Future<List<CustomerPayment>> listForCustomer(int customerId) async {
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.customerPayments,
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'id DESC',
    );
    return rows.map(CustomerPayment.fromMap).toList();
  }
}
