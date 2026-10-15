import 'package:sqflite/sqflite.dart';

import '../../core/currency/currency.dart';
import '../../core/database/app_database.dart';
import '../../core/database/schema.dart';
import '../../core/utils/digits.dart';
import '../models/app_settings.dart';

/// Typed access to the `settings` key-value table and the exchange-rate
/// history.
class SettingsRepository {
  SettingsRepository(this._appDb);

  final AppDatabase _appDb;

  static void validateRate(double rate) {
    if (!rate.isFinite || rate <= 0) {
      throw ArgumentError.value(
        rate,
        'rate',
        'Exchange rate must be a positive number',
      );
    }
  }

  static void validateRoundingStep(int step) {
    if (!kSypRoundingSteps.contains(step)) {
      throw ArgumentError.value(step, 'step', 'Unsupported rounding step');
    }
  }

  Future<AppSettings> load() async {
    final db = await _appDb.database;
    final rows = await db.query(Tables.settings);
    return AppSettings.fromMap({
      for (final row in rows) row['key'] as String: row['value'] as String,
    });
  }

  /// Completes the first-run setup in one atomic step.
  Future<void> completeSetup({
    required Currency baseCurrency,
    required double exchangeRate,
    required int sypRoundingStep,
    String? storeName,
  }) async {
    validateRate(exchangeRate);
    validateRoundingStep(sypRoundingStep);
    await _appDb.runInTransaction((txn) async {
      await _put(txn, SettingKeys.baseCurrency, baseCurrency.code);
      await _put(txn, SettingKeys.exchangeRate, exchangeRate.toString());
      await _put(txn, SettingKeys.sypRoundingStep, '$sypRoundingStep');
      if (storeName != null) {
        await _put(txn, SettingKeys.storeName, storeName.trim());
      }
      await _insertRateHistory(txn, exchangeRate);
      await _put(txn, SettingKeys.setupCompleted, '1');
    });
  }

  /// Updates the current rate and appends it to the history, atomically.
  /// Does nothing when [rate] equals the current rate.
  Future<void> updateExchangeRate(double rate) async {
    validateRate(rate);
    await _appDb.runInTransaction((txn) async {
      final rows = await txn.query(
        Tables.settings,
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [SettingKeys.exchangeRate],
      );
      final current =
          rows.isEmpty ? null : double.tryParse(rows.first['value'] as String);
      if (current == rate) return;
      await _put(txn, SettingKeys.exchangeRate, rate.toString());
      await _insertRateHistory(txn, rate);
    });
  }

  Future<void> setBaseCurrency(Currency currency) =>
      _set(SettingKeys.baseCurrency, currency.code);

  Future<void> setSypRoundingStep(int step) async {
    validateRoundingStep(step);
    await _set(SettingKeys.sypRoundingStep, '$step');
  }

  Future<void> setShowDualCurrency(bool value) =>
      _set(SettingKeys.showDualCurrency, value ? '1' : '0');

  Future<void> setDigitStyle(DigitStyle style) =>
      _set(SettingKeys.digitStyle, style.storageValue);

  Future<void> setLanguage(String language) async {
    if (language != 'ar' && language != 'en') {
      throw ArgumentError.value(language, 'language', 'Use "ar" or "en"');
    }
    await _set(SettingKeys.language, language);
  }

  Future<void> setDefaultLowStockThreshold(int value) async {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Must not be negative');
    }
    await _set(SettingKeys.defaultLowStockThreshold, '$value');
  }

  Future<void> setAllowNegativeStock(bool value) =>
      _set(SettingKeys.allowNegativeStock, value ? '1' : '0');

  Future<void> setStoreName(String name) =>
      _set(SettingKeys.storeName, name.trim());

  Future<void> _set(String key, String value) async {
    final db = await _appDb.database;
    await _put(db, key, value);
  }

  Future<void> _put(DatabaseExecutor executor, String key, String value) {
    return executor.insert(
      Tables.settings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _insertRateHistory(DatabaseExecutor executor, double rate) {
    return executor.insert(Tables.exchangeRateHistory, {
      'rate': rate,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
