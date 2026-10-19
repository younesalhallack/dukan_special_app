import '../../core/database/app_database.dart';
import '../../core/database/schema.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/arabic_normalizer.dart';
import '../../core/utils/digits.dart';
import '../../core/utils/sql_utils.dart';
import '../models/supplier.dart';
import '../models/supplier_balance.dart';
import 'supplier_balance_queries.dart';

/// Supplier CRUD, search and balances. Suppliers are never hard-deleted:
/// they are hidden, and only when the shop owes them nothing.
class SupplierRepository {
  SupplierRepository(this._appDb);

  final AppDatabase _appDb;

  /// Suppliers matching [query] (every word must match the name or phone).
  Future<List<Supplier>> list({
    String query = '',
    bool includeInactive = false,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (!includeInactive) where.add('is_active = 1');
    for (final token in ArabicNormalizer.tokens(query)) {
      final like = '%${escapeLike(token)}%';
      where.add(
        "(name_normalized LIKE ? ESCAPE '\\' OR phone LIKE ? ESCAPE '\\')",
      );
      args
        ..add(like)
        ..add(like);
    }
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.suppliers,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name_normalized, id',
    );
    return rows.map(Supplier.fromMap).toList();
  }

  /// Like [list], with each supplier's balance.
  Future<List<SupplierWithBalance>> listWithBalances({String query = ''}) async {
    final suppliers = await list(query: query);
    final db = await _appDb.database;
    final balances = await SupplierBalanceQueries.forAll(db);
    return [
      for (final supplier in suppliers)
        SupplierWithBalance(
          supplier: supplier,
          balance: balances[supplier.id] ?? SupplierBalance.zero,
        ),
    ];
  }

  Future<Supplier?> getById(int id) async {
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.suppliers,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Supplier.fromMap(rows.first);
  }

  Future<SupplierBalance> balanceOf(int supplierId) async {
    final db = await _appDb.database;
    return SupplierBalanceQueries.forSupplier(db, supplierId);
  }

  Future<int> create(SupplierInput input) async {
    _validate(input);
    final db = await _appDb.database;
    return db.insert(Tables.suppliers, {
      ..._row(input),
      'is_active': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> update(int id, SupplierInput input) async {
    _validate(input);
    final db = await _appDb.database;
    final changed = await db.update(
      Tables.suppliers,
      _row(input),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (changed == 0) throw const AppException(AppError.notFound);
  }

  /// Hides or shows a supplier. A supplier the shop owes (or holds an advance
  /// with) cannot be hidden.
  Future<void> setActive(int id, bool active) async {
    await _appDb.runInTransaction((txn) async {
      if (!active) {
        final balance = await SupplierBalanceQueries.forSupplier(txn, id);
        if (!balance.isZero) {
          throw const AppException(AppError.supplierHasDebt);
        }
      }
      final changed = await txn.update(
        Tables.suppliers,
        {'is_active': active ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 0) throw const AppException(AppError.notFound);
    });
  }

  static void _validate(SupplierInput input) {
    if (input.name.trim().isEmpty) {
      throw const AppException(AppError.invalidName);
    }
  }

  static Map<String, Object?> _row(SupplierInput input) {
    String? clean(String? value) {
      final text = (value ?? '').trim();
      return text.isEmpty ? null : text;
    }

    final phone = clean(input.phone);
    return {
      'name': input.name.trim(),
      'name_normalized': ArabicNormalizer.normalize(input.name),
      'phone': phone == null ? null : Digits.toWestern(phone),
      'notes': clean(input.notes),
    };
  }
}
