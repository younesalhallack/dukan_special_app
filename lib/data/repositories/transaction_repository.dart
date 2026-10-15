import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/database/schema.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/checkout_request.dart';
import '../models/sale_transaction.dart';
import '../models/stock_movement.dart';
import '../models/transaction_item.dart';

/// Records sales, reads invoices and voids them. Everything that touches
/// several tables runs in ONE database transaction.
class TransactionRepository {
  TransactionRepository(this._appDb);

  final AppDatabase _appDb;

  /// Saves the invoice, its lines, the stock deduction and the stock
  /// movements atomically, and returns the new invoice id. The exchange rate
  /// of [request] is stored on the invoice. If anything fails, nothing is
  /// saved (including the invoice number).
  Future<int> checkout(CheckoutRequest request) async {
    _validate(request);
    return _appDb.runInTransaction((txn) async {
      final now = DateTime.now().toUtc().toIso8601String();
      final allowNegative = await _allowNegativeStock(txn);

      // The same product may appear on several lines: check the sum.
      final needed = <int, double>{};
      for (final line in request.lines) {
        needed[line.productId] = (needed[line.productId] ?? 0) + line.quantity;
      }
      for (final entry in needed.entries) {
        final rows = await txn.query(
          Tables.products,
          columns: ['quantity'],
          where: 'id = ?',
          whereArgs: [entry.key],
          limit: 1,
        );
        if (rows.isEmpty) throw const AppException(AppError.notFound);
        final stock = (rows.first['quantity'] as num).toDouble();
        final wanted = double.parse(entry.value.toStringAsFixed(3));
        if (!allowNegative && stock < wanted) {
          throw const AppException(AppError.insufficientStock);
        }
      }

      final subtotal =
          request.lines.fold<int>(0, (sum, line) => sum + line.lineTotal);
      final total = subtotal - request.discountAmount;
      final totalCost =
          request.lines.fold<int>(0, (sum, line) => sum + line.lineCost);
      final paid = request.paymentType == PaymentType.cash
          ? total
          : (request.paidAmount ?? 0);

      final number = await _nextInvoiceNumber(txn);
      final invoiceId = await txn.insert(Tables.transactions, {
        'invoice_number': number,
        'customer_id': request.customerId,
        'currency': request.currency.code,
        'exchange_rate': request.exchangeRate,
        'total_amount': total,
        'discount_amount': request.discountAmount,
        'paid_amount': paid,
        'total_cost': totalCost,
        'payment_type': request.paymentType.code,
        'status': InvoiceStatus.completed.code,
        'note': request.note,
        'created_at': now,
      });

      for (final line in request.lines) {
        await txn.insert(Tables.transactionItems, {
          'transaction_id': invoiceId,
          'product_id': line.productId,
          'product_name': line.productName,
          'quantity': line.quantity,
          'unit_price': line.unitPrice,
          'unit_cost': line.unitCost,
          'line_total': line.lineTotal,
        });
        await txn.rawUpdate(
          'UPDATE ${Tables.products} '
          'SET quantity = ROUND(quantity - ?, 3), updated_at = ? WHERE id = ?',
          [line.quantity, now, line.productId],
        );
        await txn.insert(Tables.stockMovements, {
          'product_id': line.productId,
          'change_qty': -line.quantity,
          'reason': StockReasons.sale,
          'ref_transaction_id': invoiceId,
          'created_at': now,
        });
      }
      return invoiceId;
    });
  }

  /// Invoices, newest first. [from] is inclusive and [to] exclusive.
  Future<List<SaleTransaction>> list({
    DateTime? from,
    DateTime? to,
    bool includeVoided = true,
    int? customerId,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('created_at >= ?');
      args.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      where.add('created_at < ?');
      args.add(to.toUtc().toIso8601String());
    }
    if (customerId != null) {
      where.add('customer_id = ?');
      args.add(customerId);
    }
    if (!includeVoided) where.add("status = 'completed'");
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.transactions,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'id DESC',
    );
    return rows.map(SaleTransaction.fromMap).toList();
  }

  Future<InvoiceDetails?> getWithItems(int id) async {
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.transactions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final items = await db.query(
      Tables.transactionItems,
      where: 'transaction_id = ?',
      whereArgs: [id],
      orderBy: 'id',
    );
    return InvoiceDetails(
      transaction: SaleTransaction.fromMap(rows.first),
      items: items.map(TransactionItem.fromMap).toList(),
    );
  }

  /// Cancels a whole invoice: the quantities go back to the stock (logged as
  /// `void` movements) and the invoice stays in the history, marked voided.
  Future<void> voidInvoice(int id) async {
    await _appDb.runInTransaction((txn) async {
      final rows = await txn.query(
        Tables.transactions,
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw const AppException(AppError.notFound);
      if (rows.first['status'] == InvoiceStatus.voided.code) {
        throw const AppException(AppError.alreadyVoided);
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.update(
        Tables.transactions,
        {'status': InvoiceStatus.voided.code},
        where: 'id = ?',
        whereArgs: [id],
      );
      final items = await txn.query(
        Tables.transactionItems,
        where: 'transaction_id = ?',
        whereArgs: [id],
      );
      for (final item in items) {
        final productId = item['product_id'] as int?;
        if (productId == null) continue;
        final quantity = (item['quantity'] as num).toDouble();
        await txn.rawUpdate(
          'UPDATE ${Tables.products} '
          'SET quantity = ROUND(quantity + ?, 3), updated_at = ? WHERE id = ?',
          [quantity, now, productId],
        );
        await txn.insert(Tables.stockMovements, {
          'product_id': productId,
          'change_qty': quantity,
          'reason': StockReasons.voidSale,
          'ref_transaction_id': id,
          'created_at': now,
        });
      }
    });
  }

  // ---------------------------------------------------------------------------

  static void _validate(CheckoutRequest request) {
    if (request.lines.isEmpty) throw const AppException(AppError.emptyCart);
    if (!request.exchangeRate.isFinite || request.exchangeRate <= 0) {
      throw const AppException(AppError.invalidAmount);
    }
    var subtotal = 0;
    for (final line in request.lines) {
      if (!line.quantity.isFinite ||
          line.quantity <= 0 ||
          line.unitPrice < 0 ||
          line.unitCost < 0 ||
          line.lineTotal < 0) {
        throw const AppException(AppError.invalidAmount);
      }
      subtotal += line.lineTotal;
    }
    if (request.discountAmount < 0 || request.discountAmount > subtotal) {
      throw const AppException(AppError.invalidAmount);
    }
    if (request.paymentType == PaymentType.credit) {
      if (request.customerId == null) {
        throw const AppException(AppError.customerRequired);
      }
      final paid = request.paidAmount ?? 0;
      if (paid < 0 || paid > subtotal - request.discountAmount) {
        throw const AppException(AppError.invalidAmount);
      }
    }
  }

  static Future<bool> _allowNegativeStock(DatabaseExecutor executor) async {
    final rows = await executor.query(
      Tables.settings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [SettingKeys.allowNegativeStock],
    );
    return rows.isEmpty ? true : rows.first['value'] != '0';
  }

  /// Increments the counter stored in `settings` (inside the caller's
  /// transaction) and formats it as `INV-000001`.
  static Future<String> _nextInvoiceNumber(DatabaseExecutor executor) async {
    final rows = await executor.query(
      Tables.settings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [SettingKeys.invoiceCounter],
    );
    final current =
        rows.isEmpty ? 0 : (int.tryParse(rows.first['value'] as String) ?? 0);
    final next = current + 1;
    await executor.insert(
      Tables.settings,
      {'key': SettingKeys.invoiceCounter, 'value': '$next'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return 'INV-${next.toString().padLeft(6, '0')}';
  }
}
