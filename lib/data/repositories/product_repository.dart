import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/database/schema.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/arabic_normalizer.dart';
import '../../core/utils/digits.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';

/// Product CRUD, search, low-stock queries and audited stock adjustments.
class ProductRepository {
  ProductRepository(this._appDb);

  final AppDatabase _appDb;

  static const String _selectBase =
      'SELECT p.*, c.name AS category_name FROM ${Tables.products} p '
      'LEFT JOIN ${Tables.categories} c ON c.id = p.category_id';

  /// Active products, optionally filtered. Every word of [query] must appear
  /// in the (normalized) name or barcode.
  Future<List<Product>> list({
    String query = '',
    int? categoryId,
    bool includeInactive = false,
    int? limit,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (!includeInactive) where.add('p.is_active = 1');
    if (categoryId != null) {
      where.add('p.category_id = ?');
      args.add(categoryId);
    }
    for (final token in ArabicNormalizer.tokens(query)) {
      final like = '%${_escapeLike(token)}%';
      where.add(
        "(p.name_normalized LIKE ? ESCAPE '\\' OR p.barcode LIKE ? ESCAPE '\\')",
      );
      args
        ..add(like)
        ..add(like);
    }
    final sql = '$_selectBase'
        '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}'
        ' ORDER BY p.name_normalized'
        '${limit == null ? '' : ' LIMIT $limit'}';
    final db = await _appDb.database;
    final rows = await db.rawQuery(sql, args);
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getById(int id) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery('$_selectBase WHERE p.id = ?', [id]);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  /// Active product with exactly this barcode, or null.
  Future<Product?> findByBarcode(String barcode) async {
    final clean = _cleanBarcode(barcode);
    if (clean == null) return null;
    final db = await _appDb.database;
    final rows = await db.rawQuery(
      '$_selectBase WHERE p.barcode = ? AND p.is_active = 1',
      [clean],
    );
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  /// Product with exactly this barcode, active or hidden, or null. Used to
  /// explain a duplicate-barcode conflict.
  Future<Product?> findByBarcodeAnyStatus(String barcode) async {
    final clean = _cleanBarcode(barcode);
    if (clean == null) return null;
    final db = await _appDb.database;
    final rows = await db.rawQuery('$_selectBase WHERE p.barcode = ?', [clean]);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  /// Active products whose quantity is at or below their alert level
  /// (their own threshold, or [defaultThreshold]), lowest stock first.
  Future<List<Product>> lowStock(double defaultThreshold) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery(
      '$_selectBase WHERE p.is_active = 1 '
      'AND p.quantity <= COALESCE(p.low_stock_threshold, ?) '
      'ORDER BY p.quantity ASC, p.name_normalized',
      [defaultThreshold],
    );
    return rows.map(Product.fromMap).toList();
  }

  /// Creates a product and returns its id. A positive opening quantity is
  /// recorded as a stock movement.
  Future<int> create(ProductInput input) async {
    _validate(input);
    return _appDb.runInTransaction((txn) async {
      final now = _now();
      final row = _row(input, now);
      await _ensureBarcodeFree(txn, row['barcode'] as String?, null);
      final id = await txn.insert(Tables.products, {
        ...row,
        'quantity': input.initialQuantity,
        'is_active': 1,
        'created_at': now,
      });
      if (input.initialQuantity > 0) {
        await txn.insert(Tables.stockMovements, {
          'product_id': id,
          'change_qty': input.initialQuantity,
          'reason': StockReasons.adjustment,
          'note': StockNotes.openingStock,
          'created_at': now,
        });
      }
      return id;
    });
  }

  /// Updates the editable fields. The quantity is never touched here.
  Future<void> update(int id, ProductInput input) async {
    _validate(input);
    await _appDb.runInTransaction((txn) async {
      final row = _row(input, _now());
      await _ensureBarcodeFree(txn, row['barcode'] as String?, id);
      final changed = await txn.update(
        Tables.products,
        row,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 0) throw const AppException(AppError.notFound);
    });
  }

  /// Hides (or shows) a product. Products are never hard-deleted.
  Future<void> setActive(int id, bool active) async {
    final db = await _appDb.database;
    final changed = await db.update(
      Tables.products,
      {'is_active': active ? 1 : 0, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (changed == 0) throw const AppException(AppError.notFound);
  }

  /// Changes the quantity by [delta] (positive or negative) and records a
  /// stock movement, atomically. Returns the new quantity. Manual adjustments
  /// can never make the stock negative.
  Future<double> adjustStock({
    required int productId,
    required double delta,
    required String reason,
    String? note,
  }) async {
    if (!delta.isFinite || delta == 0) {
      throw const AppException(AppError.invalidQuantity);
    }
    if (reason != StockReasons.restock && reason != StockReasons.adjustment) {
      throw ArgumentError.value(reason, 'reason', 'Use restock or adjustment');
    }
    final cleanNote = (note == null || note.trim().isEmpty) ? null : note.trim();
    return _appDb.runInTransaction((txn) async {
      final rows = await txn.query(
        Tables.products,
        columns: ['quantity'],
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (rows.isEmpty) throw const AppException(AppError.notFound);
      final current = (rows.first['quantity'] as num).toDouble();
      final next = double.parse((current + delta).toStringAsFixed(3));
      if (next < 0) throw const AppException(AppError.negativeStock);
      final now = _now();
      await txn.update(
        Tables.products,
        {'quantity': next, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [productId],
      );
      await txn.insert(Tables.stockMovements, {
        'product_id': productId,
        'change_qty': delta,
        'reason': reason,
        'note': cleanNote,
        'created_at': now,
      });
      return next;
    });
  }

  /// Stock history of a product, newest first.
  Future<List<StockMovement>> movementsFor(int productId) async {
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.stockMovements,
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'id DESC',
    );
    return rows.map(StockMovement.fromMap).toList();
  }

  // ---------------------------------------------------------------------------

  static void _validate(ProductInput input) {
    if (input.name.trim().isEmpty) {
      throw const AppException(AppError.invalidName);
    }
    if (input.costPrice < 0 || input.salePrice < 0) {
      throw const AppException(AppError.invalidPrice);
    }
    final threshold = input.lowStockThreshold;
    if (threshold != null && (!threshold.isFinite || threshold < 0)) {
      throw const AppException(AppError.invalidQuantity);
    }
    if (!input.initialQuantity.isFinite || input.initialQuantity < 0) {
      throw const AppException(AppError.invalidQuantity);
    }
  }

  static Map<String, Object?> _row(ProductInput input, String now) {
    return {
      'category_id': input.categoryId,
      'name': input.name.trim(),
      'name_normalized': ArabicNormalizer.normalize(input.name),
      'barcode': _cleanBarcode(input.barcode),
      'cost_price': input.costPrice,
      'cost_currency': input.costCurrency.code,
      'sale_price': input.salePrice,
      'sale_currency': input.saleCurrency.code,
      'low_stock_threshold': input.lowStockThreshold,
      'updated_at': now,
    };
  }

  static String? _cleanBarcode(String? raw) {
    final value = Digits.toWestern((raw ?? '').trim());
    return value.isEmpty ? null : value;
  }

  static Future<void> _ensureBarcodeFree(
    DatabaseExecutor executor,
    String? barcode,
    int? exceptId,
  ) async {
    if (barcode == null) return;
    final rows = await executor.query(
      Tables.products,
      columns: ['id'],
      where: exceptId == null ? 'barcode = ?' : 'barcode = ? AND id != ?',
      whereArgs: exceptId == null ? [barcode] : [barcode, exceptId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      throw const AppException(AppError.duplicateBarcode);
    }
  }

  static String _escapeLike(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  static String _now() => DateTime.now().toUtc().toIso8601String();
}
