import 'package:sqflite/sqflite.dart';

import '../../core/currency/currency.dart';
import '../../core/currency/money.dart';
import '../../core/database/app_database.dart';
import '../../core/database/schema.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/purchase.dart';
import '../models/purchase_request.dart';
import '../models/sale_transaction.dart';
import '../models/stock_movement.dart';

/// Records purchase invoices, reads them and voids them. Everything that
/// touches several tables runs in ONE database transaction.
class PurchaseRepository {
  PurchaseRepository(this._appDb);

  final AppDatabase _appDb;

  /// Saves the invoice and its lines, adds the quantities to the stock
  /// (logged as `restock` movements linked to the invoice) and, when
  /// [PurchaseRequest.updateCosts] is true, sets each product's cost to the
  /// unit cost of this invoice (converted to the product's cost currency at
  /// the invoice rate). Returns the new purchase id. If anything fails,
  /// nothing is saved (including the purchase number).
  Future<int> create(PurchaseRequest request) async {
    _validate(request);
    return _appDb.runInTransaction((txn) async {
      final now = DateTime.now().toUtc().toIso8601String();

      final supplierId = request.supplierId;
      if (supplierId != null) {
        final rows = await txn.query(
          Tables.suppliers,
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [supplierId],
          limit: 1,
        );
        if (rows.isEmpty) throw const AppException(AppError.notFound);
      }

      // Every product must exist; remember its cost currency.
      final costCurrencies = <int, Currency>{};
      for (final id in request.lines.map((line) => line.productId).toSet()) {
        final rows = await txn.query(
          Tables.products,
          columns: ['cost_currency'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isEmpty) throw const AppException(AppError.notFound);
        costCurrencies[id] = Currency.fromCode(rows.first['cost_currency'] as String);
      }

      final subtotal =
          request.lines.fold<int>(0, (sum, line) => sum + line.lineTotal);
      final total = subtotal - request.discountAmount;
      final paid = request.paymentType == PaymentType.cash
          ? total
          : (request.paidAmount ?? 0);

      final number = await _nextPurchaseNumber(txn);
      final purchaseId = await txn.insert(Tables.purchases, {
        'purchase_number': number,
        'supplier_id': supplierId,
        'supplier_invoice_number': _clean(request.supplierInvoiceNumber),
        'currency': request.currency.code,
        'exchange_rate': request.exchangeRate,
        'total_amount': total,
        'discount_amount': request.discountAmount,
        'paid_amount': paid,
        'payment_type': request.paymentType.code,
        'status': InvoiceStatus.completed.code,
        'note': _clean(request.note),
        'purchase_date': request.purchaseDate.toUtc().toIso8601String(),
        'created_at': now,
      });

      for (final line in request.lines) {
        await txn.insert(Tables.purchaseItems, {
          'purchase_id': purchaseId,
          'product_id': line.productId,
          'product_name': line.productName,
          'quantity': line.quantity,
          'unit_cost': line.unitCost,
          'line_total': line.lineTotal,
        });
        await txn.rawUpdate(
          'UPDATE ${Tables.products} '
          'SET quantity = ROUND(quantity + ?, 3), updated_at = ? WHERE id = ?',
          [line.quantity, now, line.productId],
        );
        await txn.insert(Tables.stockMovements, {
          'product_id': line.productId,
          'change_qty': line.quantity,
          'reason': StockReasons.restock,
          'ref_purchase_id': purchaseId,
          'created_at': now,
        });
        // A line without a cost does not change the product's cost.
        if (request.updateCosts && line.unitCost > 0) {
          final productCurrency = costCurrencies[line.productId]!;
          final newCost = Money.convert(
            line.unitCost,
            from: request.currency,
            to: productCurrency,
            rate: request.exchangeRate,
          );
          await txn.rawUpdate(
            'UPDATE ${Tables.products} SET cost_price = ?, updated_at = ? WHERE id = ?',
            [newCost, now, line.productId],
          );
        }
      }
      return purchaseId;
    });
  }

  /// Purchases, newest first. [from] is inclusive and [to] exclusive and
  /// both compare with the purchase date.
  Future<List<Purchase>> list({
    DateTime? from,
    DateTime? to,
    int? supplierId,
    bool includeVoided = true,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('purchase_date >= ?');
      args.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      where.add('purchase_date < ?');
      args.add(to.toUtc().toIso8601String());
    }
    if (supplierId != null) {
      where.add('supplier_id = ?');
      args.add(supplierId);
    }
    if (!includeVoided) where.add("status = 'completed'");
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.purchases,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'purchase_date DESC, id DESC',
    );
    return rows.map(Purchase.fromMap).toList();
  }

  Future<PurchaseDetails?> getWithItems(int id) async {
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.purchases,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final items = await db.query(
      Tables.purchaseItems,
      where: 'purchase_id = ?',
      whereArgs: [id],
      orderBy: 'id',
    );
    return PurchaseDetails(
      purchase: Purchase.fromMap(rows.first),
      items: items.map(PurchaseItem.fromMap).toList(),
    );
  }

  /// Cancels a whole purchase: the quantities are taken back out of the
  /// stock (logged as `void` movements, the stock may go below zero if the
  /// goods were already sold) and the purchase stays in the history, marked
  /// voided. Product costs are NOT restored.
  Future<void> voidPurchase(int id) async {
    await _appDb.runInTransaction((txn) async {
      final rows = await txn.query(
        Tables.purchases,
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
        Tables.purchases,
        {'status': InvoiceStatus.voided.code},
        where: 'id = ?',
        whereArgs: [id],
      );
      final items = await txn.query(
        Tables.purchaseItems,
        where: 'purchase_id = ?',
        whereArgs: [id],
      );
      for (final item in items) {
        final productId = item['product_id'] as int?;
        if (productId == null) continue;
        final quantity = (item['quantity'] as num).toDouble();
        await txn.rawUpdate(
          'UPDATE ${Tables.products} '
          'SET quantity = ROUND(quantity - ?, 3), updated_at = ? WHERE id = ?',
          [quantity, now, productId],
        );
        await txn.insert(Tables.stockMovements, {
          'product_id': productId,
          'change_qty': -quantity,
          'reason': StockReasons.voidSale,
          'ref_purchase_id': id,
          'created_at': now,
        });
      }
    });
  }

  // ---------------------------------------------------------------------------

  static void _validate(PurchaseRequest request) {
    if (request.lines.isEmpty) throw const AppException(AppError.emptyPurchase);
    if (!request.exchangeRate.isFinite || request.exchangeRate <= 0) {
      throw const AppException(AppError.invalidAmount);
    }
    var subtotal = 0;
    for (final line in request.lines) {
      if (!line.quantity.isFinite ||
          line.quantity <= 0 ||
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
      if (request.supplierId == null) {
        throw const AppException(AppError.supplierRequired);
      }
      final paid = request.paidAmount ?? 0;
      if (paid < 0 || paid > subtotal - request.discountAmount) {
        throw const AppException(AppError.invalidAmount);
      }
    }
  }

  static String? _clean(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }

  /// Increments the counter stored in `settings` (inside the caller's
  /// transaction) and formats it as `PUR-000001`.
  static Future<String> _nextPurchaseNumber(DatabaseExecutor executor) async {
    final rows = await executor.query(
      Tables.settings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [SettingKeys.purchaseCounter],
    );
    final current =
        rows.isEmpty ? 0 : (int.tryParse(rows.first['value'] as String) ?? 0);
    final next = current + 1;
    await executor.insert(
      Tables.settings,
      {'key': SettingKeys.purchaseCounter, 'value': '$next'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return 'PUR-${next.toString().padLeft(6, '0')}';
  }
}
