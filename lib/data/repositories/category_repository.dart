import '../../core/database/app_database.dart';
import '../../core/database/schema.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/arabic_normalizer.dart';
import '../models/category.dart';

/// Category CRUD. Deletion is soft: the category is hidden and its products
/// become uncategorized.
class CategoryRepository {
  CategoryRepository(this._appDb);

  final AppDatabase _appDb;

  Future<List<Category>> list() async {
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.categories,
      where: 'is_active = 1',
      orderBy: 'name_normalized',
    );
    return rows.map(Category.fromMap).toList();
  }

  /// Creates a category and returns its id. A hidden category with the same
  /// (normalized) name is reactivated instead of creating a duplicate.
  Future<int> create(String name) async {
    final display = _validName(name);
    final normalized = ArabicNormalizer.normalize(display);
    return _appDb.runInTransaction((txn) async {
      final existing = await txn.query(
        Tables.categories,
        where: 'name_normalized = ?',
        whereArgs: [normalized],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final row = existing.first;
        if (row['is_active'] == 1) {
          throw const AppException(AppError.duplicateCategory);
        }
        await txn.update(
          Tables.categories,
          {'name': display, 'is_active': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        return row['id'] as int;
      }
      return txn.insert(Tables.categories, {
        'name': display,
        'name_normalized': normalized,
        'is_active': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<void> rename(int id, String name) async {
    final display = _validName(name);
    final normalized = ArabicNormalizer.normalize(display);
    await _appDb.runInTransaction((txn) async {
      final clash = await txn.query(
        Tables.categories,
        columns: ['id'],
        where: 'name_normalized = ? AND id != ?',
        whereArgs: [normalized, id],
        limit: 1,
      );
      if (clash.isNotEmpty) {
        throw const AppException(AppError.duplicateCategory);
      }
      final changed = await txn.update(
        Tables.categories,
        {'name': display, 'name_normalized': normalized},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 0) throw const AppException(AppError.notFound);
    });
  }

  /// Hides the category and detaches its products, atomically.
  Future<void> delete(int id) async {
    await _appDb.runInTransaction((txn) async {
      await txn.update(
        Tables.products,
        {'category_id': null},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      final changed = await txn.update(
        Tables.categories,
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 0) throw const AppException(AppError.notFound);
    });
  }

  static String _validName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const AppException(AppError.invalidName);
    return trimmed;
  }
}
