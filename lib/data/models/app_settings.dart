import '../../core/currency/currency.dart';
import '../../core/database/schema.dart';
import '../../core/utils/digits.dart';

/// SYP rounding steps offered in the UI. 1 means "no rounding".
const List<int> kSypRoundingSteps = <int>[1, 10, 50, 100, 500, 1000];

/// Immutable snapshot of the `settings` table.
class AppSettings {
  const AppSettings({
    required this.baseCurrency,
    required this.exchangeRate,
    required this.sypRoundingStep,
    required this.showDualCurrency,
    required this.language,
    required this.digitStyle,
    required this.defaultLowStockThreshold,
    required this.allowNegativeStock,
    required this.autoBackupEnabled,
    required this.lastExportAt,
    required this.lastAutoBackupAt,
    required this.storeName,
    required this.setupCompleted,
  });

  /// Null until the first-run setup is completed.
  final Currency? baseCurrency;

  /// SYP per 1 USD. Null until the first-run setup is completed.
  final double? exchangeRate;

  final int sypRoundingStep;
  final bool showDualCurrency;

  /// `ar` or `en`.
  final String language;
  final DigitStyle digitStyle;
  final int defaultLowStockThreshold;

  /// When false, a sale cannot take the stock below zero.
  final bool allowNegativeStock;

  /// Daily internal backup when the app starts.
  final bool autoBackupEnabled;

  /// When a backup was last exported out of the app (UTC), if ever.
  final DateTime? lastExportAt;

  /// When the last automatic internal backup was made (UTC), if ever.
  final DateTime? lastAutoBackupAt;
  final String storeName;
  final bool setupCompleted;

  /// True when the app has everything it needs to start working.
  bool get isConfigured =>
      setupCompleted &&
      baseCurrency != null &&
      exchangeRate != null &&
      exchangeRate! > 0;

  /// The exchange rate; only call after [isConfigured] is true.
  double get rate {
    final value = exchangeRate;
    if (value == null) throw StateError('Exchange rate is not set yet');
    return value;
  }

  factory AppSettings.fromMap(Map<String, String> map) {
    return AppSettings(
      baseCurrency: Currency.tryFromCode(map[SettingKeys.baseCurrency]),
      exchangeRate: double.tryParse(map[SettingKeys.exchangeRate] ?? ''),
      sypRoundingStep:
          int.tryParse(map[SettingKeys.sypRoundingStep] ?? '') ?? 100,
      showDualCurrency: (map[SettingKeys.showDualCurrency] ?? '1') == '1',
      language: map[SettingKeys.language] ?? 'ar',
      digitStyle: DigitStyle.fromStorage(map[SettingKeys.digitStyle]),
      defaultLowStockThreshold:
          int.tryParse(map[SettingKeys.defaultLowStockThreshold] ?? '') ?? 5,
      allowNegativeStock: (map[SettingKeys.allowNegativeStock] ?? '1') == '1',
      autoBackupEnabled: (map[SettingKeys.autoBackupEnabled] ?? '1') == '1',
      lastExportAt: DateTime.tryParse(map[SettingKeys.lastExportAt] ?? ''),
      lastAutoBackupAt: DateTime.tryParse(map[SettingKeys.lastAutoBackupAt] ?? ''),
      storeName: map[SettingKeys.storeName] ?? '',
      setupCompleted: map[SettingKeys.setupCompleted] == '1',
    );
  }
}
