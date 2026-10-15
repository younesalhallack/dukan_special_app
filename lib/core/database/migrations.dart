import 'schema.dart';

/// Current schema version. Bump it whenever you add an entry to [migrations].
const int currentDbVersion = 3;

/// Schema upgrades, keyed by the version they upgrade TO.
///
/// Version 1 is created from `schemaV1`, so it has no entry here.
/// When you need version 2, add for example:
///
/// ```dart
/// 2: ['ALTER TABLE products ADD COLUMN unit TEXT'],
/// ```
///
/// and set [currentDbVersion] to 2. Fresh installs create v1 and then run
/// every migration in order, so both paths always end in the same schema.
const Map<int, List<String>> migrations = <int, List<String>>{
  // Version 2: invoice-level discount and the sales settings.
  2: <String>[
    'ALTER TABLE transactions ADD COLUMN discount_amount INTEGER NOT NULL DEFAULT 0',
    "INSERT OR IGNORE INTO settings(key, value) VALUES ('allow_negative_stock', '1')",
    "INSERT OR IGNORE INTO settings(key, value) VALUES ('invoice_counter', '0')",
  ],
  // Version 3: debt payments can be cancelled (kept in the ledger, ignored in balances).
  3: <String>[
    'ALTER TABLE customer_payments ADD COLUMN is_voided INTEGER NOT NULL DEFAULT 0',
  ],
};

/// Settings inserted when the database is first created.
///
/// `base_currency` and `exchange_rate` are intentionally absent: they are
/// requested in the first-run setup screen, so there is no wrong default.
const Map<String, String> defaultSettings = <String, String>{
  SettingKeys.language: 'ar',
  SettingKeys.digitStyle: 'western',
  SettingKeys.sypRoundingStep: '100',
  SettingKeys.showDualCurrency: '1',
  SettingKeys.defaultLowStockThreshold: '5',
  SettingKeys.setupCompleted: '0',
  // Also inserted by migration 2 (INSERT OR IGNORE) for databases created before it.
  SettingKeys.allowNegativeStock: '1',
  SettingKeys.invoiceCounter: '0',
};
