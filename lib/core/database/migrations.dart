import 'schema.dart';

/// Current schema version. Bump it whenever you add an entry to [migrations].
const int currentDbVersion = 4;

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
  // Version 4: suppliers, purchase invoices and supplier payments.
  4: <String>[
    """
CREATE TABLE suppliers (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  name            TEXT NOT NULL,
  name_normalized TEXT NOT NULL,
  phone           TEXT,
  notes           TEXT,
  is_active       INTEGER NOT NULL DEFAULT 1,
  created_at      TEXT NOT NULL
)
""",
    'CREATE INDEX idx_suppliers_name ON suppliers(name_normalized)',
    """
CREATE TABLE purchases (
  id                      INTEGER PRIMARY KEY AUTOINCREMENT,
  purchase_number         TEXT NOT NULL UNIQUE,
  supplier_id             INTEGER REFERENCES suppliers(id),
  supplier_invoice_number TEXT,
  currency                TEXT NOT NULL CHECK (currency IN ('USD','SYP')),
  exchange_rate           REAL NOT NULL CHECK (exchange_rate > 0),
  total_amount            INTEGER NOT NULL CHECK (total_amount >= 0),
  discount_amount         INTEGER NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
  paid_amount             INTEGER NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),
  payment_type            TEXT NOT NULL CHECK (payment_type IN ('cash','credit')),
  status                  TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed','voided')),
  note                    TEXT,
  purchase_date           TEXT NOT NULL,
  created_at              TEXT NOT NULL,
  CHECK (payment_type = 'cash' OR supplier_id IS NOT NULL)
)
""",
    'CREATE INDEX idx_purchases_date ON purchases(purchase_date)',
    'CREATE INDEX idx_purchases_supplier ON purchases(supplier_id)',
    """
CREATE TABLE purchase_items (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  purchase_id  INTEGER NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
  product_id   INTEGER REFERENCES products(id),
  product_name TEXT NOT NULL,
  quantity     REAL NOT NULL CHECK (quantity > 0),
  unit_cost    INTEGER NOT NULL CHECK (unit_cost >= 0),
  line_total   INTEGER NOT NULL CHECK (line_total >= 0)
)
""",
    'CREATE INDEX idx_purchase_items_purchase ON purchase_items(purchase_id)',
    'CREATE INDEX idx_purchase_items_product ON purchase_items(product_id)',
    """
CREATE TABLE supplier_payments (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  supplier_id      INTEGER NOT NULL REFERENCES suppliers(id),
  purchase_id      INTEGER REFERENCES purchases(id),
  amount           INTEGER NOT NULL CHECK (amount > 0),
  currency         TEXT NOT NULL CHECK (currency IN ('USD','SYP')),
  exchange_rate    REAL NOT NULL CHECK (exchange_rate > 0),
  applied_amount   INTEGER NOT NULL CHECK (applied_amount > 0),
  applied_currency TEXT NOT NULL CHECK (applied_currency IN ('USD','SYP')),
  note             TEXT,
  created_at       TEXT NOT NULL,
  is_voided        INTEGER NOT NULL DEFAULT 0
)
""",
    'CREATE INDEX idx_supplier_payments_supplier ON supplier_payments(supplier_id)',
    'ALTER TABLE stock_movements ADD COLUMN ref_purchase_id INTEGER REFERENCES purchases(id)',
    "INSERT OR IGNORE INTO settings(key, value) VALUES ('purchase_counter', '0')",
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
  SettingKeys.purchaseCounter: '0',
};
