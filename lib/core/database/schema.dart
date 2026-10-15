/// Database schema (version 1) for the POS / inventory app.
///
/// Conventions used across every table:
///  * Money is stored as INTEGER minor units (USD = cents, SYP = whole units).
///  * Exchange rate is always "SYP per 1 USD" (REAL).
///  * Timestamps are ISO-8601 strings in UTC.
///  * Each SQL statement is its own string, because sqflite's `execute`
///    runs exactly one statement at a time.
library;

/// Table names. Use these constants in repositories instead of raw strings.
abstract final class Tables {
  static const settings = 'settings';
  static const exchangeRateHistory = 'exchange_rate_history';
  static const categories = 'categories';
  static const products = 'products';
  static const customers = 'customers';
  static const transactions = 'transactions';
  static const transactionItems = 'transaction_items';
  static const customerPayments = 'customer_payments';
  static const stockMovements = 'stock_movements';
}

/// Keys stored in the `settings` key-value table.
abstract final class SettingKeys {
  static const baseCurrency = 'base_currency'; // 'USD' | 'SYP' (set at first run)
  static const exchangeRate = 'exchange_rate'; // SYP per 1 USD (set at first run)
  static const language = 'language'; // 'ar' | 'en'
  static const digitStyle = 'digit_style'; // 'western' | 'arabic_indic'
  static const sypRoundingStep = 'syp_rounding_step'; // e.g. 50, 100, 500
  static const showDualCurrency = 'show_dual_currency'; // '1' | '0'
  static const defaultLowStockThreshold = 'default_low_stock_threshold';
  static const setupCompleted = 'setup_completed'; // '1' | '0'
  static const storeName = 'store_name';
  static const allowNegativeStock = 'allow_negative_stock'; // '1' | '0'
  static const invoiceCounter = 'invoice_counter'; // last used invoice number
}

/// Every table a valid database of this app must contain.
/// Also used later to validate a backup file before restoring it.
const List<String> requiredTables = <String>[
  Tables.settings,
  Tables.exchangeRateHistory,
  Tables.categories,
  Tables.products,
  Tables.customers,
  Tables.transactions,
  Tables.transactionItems,
  Tables.customerPayments,
  Tables.stockMovements,
];

/// Version 1 of the schema, one statement per list entry.
const List<String> schemaV1 = <String>[
  """
CREATE TABLE settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
""",
  """
CREATE TABLE exchange_rate_history (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  rate       REAL NOT NULL CHECK (rate > 0),
  created_at TEXT NOT NULL
)
""",
  """
CREATE TABLE categories (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  name            TEXT NOT NULL,
  name_normalized TEXT NOT NULL UNIQUE,
  is_active       INTEGER NOT NULL DEFAULT 1,
  created_at      TEXT NOT NULL
)
""",
  """
CREATE TABLE products (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id         INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  name                TEXT NOT NULL,
  name_normalized     TEXT NOT NULL,
  barcode             TEXT,
  cost_price          INTEGER NOT NULL DEFAULT 0 CHECK (cost_price >= 0),
  cost_currency       TEXT NOT NULL DEFAULT 'USD' CHECK (cost_currency IN ('USD','SYP')),
  sale_price          INTEGER NOT NULL DEFAULT 0 CHECK (sale_price >= 0),
  sale_currency       TEXT NOT NULL DEFAULT 'USD' CHECK (sale_currency IN ('USD','SYP')),
  quantity            REAL NOT NULL DEFAULT 0,
  low_stock_threshold REAL,
  is_active           INTEGER NOT NULL DEFAULT 1,
  created_at          TEXT NOT NULL,
  updated_at          TEXT NOT NULL
)
""",
  'CREATE UNIQUE INDEX idx_products_barcode ON products(barcode) WHERE barcode IS NOT NULL',
  'CREATE INDEX idx_products_name ON products(name_normalized)',
  'CREATE INDEX idx_products_category ON products(category_id)',
  """
CREATE TABLE customers (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  name            TEXT NOT NULL,
  name_normalized TEXT NOT NULL,
  phone           TEXT,
  notes           TEXT,
  is_active       INTEGER NOT NULL DEFAULT 1,
  created_at      TEXT NOT NULL
)
""",
  'CREATE INDEX idx_customers_name ON customers(name_normalized)',
  """
CREATE TABLE transactions (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_number TEXT NOT NULL UNIQUE,
  customer_id    INTEGER REFERENCES customers(id),
  currency       TEXT NOT NULL CHECK (currency IN ('USD','SYP')),
  exchange_rate  REAL NOT NULL CHECK (exchange_rate > 0),
  total_amount   INTEGER NOT NULL CHECK (total_amount >= 0),
  paid_amount    INTEGER NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),
  total_cost     INTEGER NOT NULL DEFAULT 0,
  payment_type   TEXT NOT NULL CHECK (payment_type IN ('cash','credit')),
  status         TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed','voided')),
  note           TEXT,
  created_at     TEXT NOT NULL,
  CHECK (payment_type = 'cash' OR customer_id IS NOT NULL)
)
""",
  'CREATE INDEX idx_tx_created ON transactions(created_at)',
  'CREATE INDEX idx_tx_customer ON transactions(customer_id)',
  """
CREATE TABLE transaction_items (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  product_id     INTEGER REFERENCES products(id),
  product_name   TEXT NOT NULL,
  quantity       REAL NOT NULL CHECK (quantity > 0),
  unit_price     INTEGER NOT NULL,
  unit_cost      INTEGER NOT NULL,
  line_total     INTEGER NOT NULL
)
""",
  'CREATE INDEX idx_items_tx ON transaction_items(transaction_id)',
  'CREATE INDEX idx_items_product ON transaction_items(product_id)',
  """
CREATE TABLE customer_payments (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id      INTEGER NOT NULL REFERENCES customers(id),
  transaction_id   INTEGER REFERENCES transactions(id),
  amount           INTEGER NOT NULL CHECK (amount > 0),
  currency         TEXT NOT NULL CHECK (currency IN ('USD','SYP')),
  exchange_rate    REAL NOT NULL CHECK (exchange_rate > 0),
  applied_amount   INTEGER NOT NULL CHECK (applied_amount > 0),
  applied_currency TEXT NOT NULL CHECK (applied_currency IN ('USD','SYP')),
  note             TEXT,
  created_at       TEXT NOT NULL
)
""",
  'CREATE INDEX idx_payments_customer ON customer_payments(customer_id)',
  """
CREATE TABLE stock_movements (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id         INTEGER NOT NULL REFERENCES products(id),
  change_qty         REAL NOT NULL,
  reason             TEXT NOT NULL CHECK (reason IN ('sale','restock','adjustment','void')),
  ref_transaction_id INTEGER REFERENCES transactions(id),
  note               TEXT,
  created_at         TEXT NOT NULL
)
""",
  'CREATE INDEX idx_stock_product ON stock_movements(product_id)',
];
