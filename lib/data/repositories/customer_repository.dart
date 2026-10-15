import '../../core/database/app_database.dart';
import '../../core/database/schema.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/arabic_normalizer.dart';
import '../../core/utils/digits.dart';
import '../../core/utils/sql_utils.dart';
import '../models/customer.dart';
import '../models/customer_balance.dart';
import 'balance_queries.dart';

/// Customer CRUD, search and balances. Customers are never hard-deleted:
/// they are hidden, and only when they owe nothing.
class CustomerRepository {
  CustomerRepository(this._appDb);

  final AppDatabase _appDb;

  /// Customers matching [query] (every word must match the name or phone).
  Future<List<Customer>> list({
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
      Tables.customers,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name_normalized, id',
    );
    return rows.map(Customer.fromMap).toList();
  }

  /// Like [list], with each customer's balance.
  Future<List<CustomerWithBalance>> listWithBalances({String query = ''}) async {
    final customers = await list(query: query);
    final db = await _appDb.database;
    final balances = await BalanceQueries.forAll(db);
    return [
      for (final customer in customers)
        CustomerWithBalance(
          customer: customer,
          balance: balances[customer.id] ?? CustomerBalance.zero,
        ),
    ];
  }

  Future<Customer?> getById(int id) async {
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.customers,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Customer.fromMap(rows.first);
  }

  Future<CustomerBalance> balanceOf(int customerId) async {
    final db = await _appDb.database;
    return BalanceQueries.forCustomer(db, customerId);
  }

  Future<int> create(CustomerInput input) async {
    _validate(input);
    final db = await _appDb.database;
    return db.insert(Tables.customers, {
      ..._row(input),
      'is_active': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> update(int id, CustomerInput input) async {
    _validate(input);
    final db = await _appDb.database;
    final changed = await db.update(
      Tables.customers,
      _row(input),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (changed == 0) throw const AppException(AppError.notFound);
  }

  /// Hides or shows a customer. A customer with a debt (or a credit balance)
  /// cannot be hidden.
  Future<void> setActive(int id, bool active) async {
    await _appDb.runInTransaction((txn) async {
      if (!active) {
        final balance = await BalanceQueries.forCustomer(txn, id);
        if (!balance.isZero) {
          throw const AppException(AppError.customerHasDebt);
        }
      }
      final changed = await txn.update(
        Tables.customers,
        {'is_active': active ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 0) throw const AppException(AppError.notFound);
    });
  }

  static void _validate(CustomerInput input) {
    if (input.name.trim().isEmpty) {
      throw const AppException(AppError.invalidName);
    }
  }

  static Map<String, Object?> _row(CustomerInput input) {
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
