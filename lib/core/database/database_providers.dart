import 'package:dukan_special_app/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app-wide database. Override in tests with `AppDatabase.forTesting`.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});
