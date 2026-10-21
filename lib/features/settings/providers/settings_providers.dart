import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utils/digits.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

/// Holds the current [AppSettings]. Every change is written to the database
/// and then re-published, so all screens rebuild with the new values
/// (for example SYP prices after an exchange-rate update).
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.watch(settingsRepositoryProvider).load();

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> _mutate(
    Future<void> Function(SettingsRepository repo) action,
  ) async {
    await action(_repo);
    state = AsyncData(await _repo.load());
  }

  Future<void> completeSetup({
    required Currency baseCurrency,
    required double exchangeRate,
    required int sypRoundingStep,
  }) {
    return _mutate(
      (r) => r.completeSetup(
        baseCurrency: baseCurrency,
        exchangeRate: exchangeRate,
        sypRoundingStep: sypRoundingStep,
      ),
    );
  }

  Future<void> updateExchangeRate(double rate) =>
      _mutate((r) => r.updateExchangeRate(rate));

  Future<void> setBaseCurrency(Currency currency) =>
      _mutate((r) => r.setBaseCurrency(currency));

  Future<void> setSypRoundingStep(int step) =>
      _mutate((r) => r.setSypRoundingStep(step));

  Future<void> setShowDualCurrency(bool value) =>
      _mutate((r) => r.setShowDualCurrency(value));

  Future<void> setDigitStyle(DigitStyle style) =>
      _mutate((r) => r.setDigitStyle(style));

  Future<void> setLanguage(String language) =>
      _mutate((r) => r.setLanguage(language));

  Future<void> setAllowNegativeStock(bool value) =>
      _mutate((r) => r.setAllowNegativeStock(value));

  Future<void> setStoreName(String name) =>
      _mutate((r) => r.setStoreName(name));

  Future<void> setAutoBackupEnabled(bool value) =>
      _mutate((r) => r.setAutoBackupEnabled(value));

  Future<void> markExported(DateTime at) =>
      _mutate((r) => r.markExported(at));

  Future<void> markAutoBackup(DateTime at) =>
      _mutate((r) => r.markAutoBackup(at));
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
