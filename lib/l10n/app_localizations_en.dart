// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Dukan';

  @override
  String get setupTitle => 'Initial setup';

  @override
  String get baseCurrency => 'Base currency';

  @override
  String get currencyUsd => 'Dollar (USD)';

  @override
  String get currencySyp => 'Pound (SYP)';

  @override
  String get exchangeRateLabel => 'Exchange rate (SYP per 1 USD)';

  @override
  String get roundingStepLabel => 'Round SYP sale prices up to';

  @override
  String get noRounding => 'No rounding';

  @override
  String get startUsing => 'Start using the app';

  @override
  String get invalidRate => 'Enter a valid exchange rate greater than zero';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get currentRate => 'Current exchange rate';

  @override
  String get updateRate => 'Update exchange rate';

  @override
  String get edit => 'Edit';

  @override
  String get rateUpdated => 'Exchange rate updated';

  @override
  String get largeChangeTitle => 'Large rate change';

  @override
  String largeChangeMessage(String newRate, String oldRate) {
    return 'The new rate ($newRate) is very different from the current rate ($oldRate). Are you sure?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get showDualCurrency => 'Show prices in both currencies';

  @override
  String get digitStyle => 'Digit style';

  @override
  String get digitsWestern => '0-9';

  @override
  String get digitsArabicIndic => '٠-٩';

  @override
  String get language => 'Language';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get homePlaceholder =>
      'Coming next: products, point of sale, customers';

  @override
  String get homeDemoTitle => 'Conversion example at the current rate';

  @override
  String get products => 'Products';

  @override
  String get categories => 'Categories';

  @override
  String get lowStock => 'Low stock';

  @override
  String get searchProducts => 'Search by name or barcode';

  @override
  String get allCategories => 'All';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get noProducts => 'No products yet';

  @override
  String get addProduct => 'Add product';

  @override
  String get editProduct => 'Edit product';

  @override
  String get productName => 'Product name';

  @override
  String get category => 'Category';

  @override
  String get barcode => 'Barcode';

  @override
  String get costPrice => 'Cost price';

  @override
  String get salePrice => 'Sale price';

  @override
  String get lowStockThresholdLabel => 'Low-stock alert level (optional)';

  @override
  String get initialQuantity => 'Opening quantity (optional)';

  @override
  String get adjustStock => 'Adjust stock';

  @override
  String get addStock => 'Add stock';

  @override
  String get reduceStock => 'Reduce / correct';

  @override
  String get quantityField => 'Quantity';

  @override
  String get note => 'Note (optional)';

  @override
  String currentQuantity(String qty) {
    return 'Current quantity: $qty';
  }

  @override
  String quantityShort(String qty) {
    return 'Qty: $qty';
  }

  @override
  String thresholdValue(String threshold) {
    return 'Level: $threshold';
  }

  @override
  String get lowStockBadge => 'Low stock';

  @override
  String get deactivate => 'Hide product';

  @override
  String get deactivateConfirm =>
      'This product will disappear from lists and sales. Its old invoices stay unchanged.';

  @override
  String profitMargin(String percent) {
    return 'Approx. profit margin: $percent';
  }

  @override
  String get newCategory => 'New category';

  @override
  String get categoryName => 'Category name';

  @override
  String get rename => 'Rename';

  @override
  String get delete => 'Delete';

  @override
  String get deleteCategoryConfirm =>
      'Delete this category? Its products become uncategorized.';

  @override
  String get noCategories => 'No categories yet';

  @override
  String get noLowStock => 'No low-stock products';

  @override
  String get errInvalidName => 'Enter a valid name';

  @override
  String get errInvalidPrice => 'Enter a valid price';

  @override
  String get errInvalidQuantity => 'Enter a valid quantity';

  @override
  String get errDuplicateBarcode =>
      'This barcode is already used by another product';

  @override
  String get errDuplicateCategory => 'A category with this name already exists';

  @override
  String get errNegativeStock => 'The quantity cannot go below zero';

  @override
  String get errNotFound => 'Item not found';

  @override
  String get scanBarcode => 'Scan barcode';

  @override
  String get scanHint => 'Point the camera at the barcode';

  @override
  String get enterManually => 'Enter manually';

  @override
  String get torch => 'Flashlight';

  @override
  String get switchCamera => 'Switch camera';

  @override
  String get cameraPermissionDenied =>
      'The app is not allowed to use the camera. Enable the camera permission in the device settings and try again, or enter the barcode manually.';

  @override
  String get cameraUnavailable =>
      'No camera is available on this device. Enter the barcode manually.';

  @override
  String get cameraError =>
      'The camera could not be started. Enter the barcode manually.';

  @override
  String barcodeUsedBy(String name) {
    return 'This barcode belongs to the product: $name';
  }

  @override
  String barcodeUsedByHidden(String name) {
    return 'This barcode is reserved by a hidden product: $name';
  }

  @override
  String get openProduct => 'Open product';

  @override
  String get pos => 'Point of sale';

  @override
  String get salesHistory => 'Sales history';

  @override
  String get searchOrScan => 'Search by name or scan barcode';

  @override
  String get cartEmpty => 'The cart is empty';

  @override
  String get clearCart => 'Clear cart';

  @override
  String get clearCartConfirm => 'Remove every product from the cart?';

  @override
  String scanAdded(String name) {
    return 'Added: $name';
  }

  @override
  String scanNotFound(String code) {
    return 'No product has this barcode: $code';
  }

  @override
  String get continuousScanHint =>
      'Scan the products one after another, then go back to check out';

  @override
  String get quantityEdit => 'Edit quantity';

  @override
  String get setDiscount => 'Set discount';

  @override
  String get discount => 'Discount';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get total => 'Total';

  @override
  String get invoiceCurrency => 'Invoice currency';

  @override
  String get checkout => 'Check out';

  @override
  String get exceedsStock => 'The quantity is more than the stock';

  @override
  String get exceedsStockWarning =>
      'Some products exceed the available stock and will go below zero. Continue?';

  @override
  String get received => 'Amount received';

  @override
  String get receivedLessThanTotal =>
      'The amount received is less than the total';

  @override
  String get change => 'Change';

  @override
  String get confirmSale => 'Confirm sale';

  @override
  String get saleDone => 'Sale completed';

  @override
  String invoiceNumberLabel(String number) {
    return 'Invoice $number';
  }

  @override
  String get newInvoice => 'New invoice';

  @override
  String get invoiceDetails => 'Invoice details';

  @override
  String get today => 'Today';

  @override
  String salesCount(String count) {
    return 'Invoices: $count';
  }

  @override
  String get totalSalesBase => 'Total sales (base currency)';

  @override
  String get profit => 'Profit';

  @override
  String get cost => 'Cost';

  @override
  String get noInvoices => 'No invoices on this day';

  @override
  String get invoiceVoided => 'Voided';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentCredit => 'Credit';

  @override
  String get payment => 'Payment';

  @override
  String get voidInvoice => 'Void invoice';

  @override
  String get voidConfirm =>
      'The invoice will be voided and its quantities returned to the stock. This cannot be undone.';

  @override
  String get voidDone => 'Invoice voided';

  @override
  String get date => 'Date';

  @override
  String get exchangeRateUsed => 'Exchange rate used';

  @override
  String get storeName => 'Store name';

  @override
  String get allowNegativeStock => 'Allow selling more than the stock';

  @override
  String get errEmptyCart => 'The cart is empty';

  @override
  String get errInvalidAmount => 'The amount is not valid';

  @override
  String get errInsufficientStock =>
      'The requested quantity is more than the stock';

  @override
  String get errAlreadyVoided => 'This invoice is already voided';

  @override
  String get errCustomerRequired => 'Choose a customer for a credit sale';

  @override
  String get customers => 'Customers';

  @override
  String get addCustomer => 'Add customer';

  @override
  String get editCustomer => 'Edit customer';

  @override
  String get customerName => 'Customer name';

  @override
  String get phone => 'Phone';

  @override
  String get notes => 'Notes';

  @override
  String get searchCustomers => 'Search by name or phone';

  @override
  String get onlyWithDebt => 'Only with debt';

  @override
  String get sortByName => 'Sort by name';

  @override
  String get sortByDebt => 'Sort by highest debt';

  @override
  String get noCustomers => 'No customers yet';

  @override
  String get totalDebts => 'Total debts owed';

  @override
  String customersWithDebt(String count) {
    return 'Customers with debt: $count';
  }

  @override
  String get debtEquivalent =>
      'Equivalent in the base currency at the current rate';

  @override
  String get balance => 'Balance';

  @override
  String get owes => 'Owes';

  @override
  String get creditInFavor => 'Customer credit';

  @override
  String get noDebt => 'No debt';

  @override
  String get recordPayment => 'Record payment';

  @override
  String get copyStatement => 'Copy balance summary';

  @override
  String get statementCopied => 'Balance summary copied';

  @override
  String statementHeader(String name) {
    return 'Customer statement: $name';
  }

  @override
  String statementDate(String date) {
    return 'Date: $date';
  }

  @override
  String get statementOwed => 'Amount due';

  @override
  String get statementCredit => 'Credit in the customer\'s favour';

  @override
  String get statementSettled => 'No amount is due.';

  @override
  String ledgerInvoice(String number) {
    return 'Invoice $number';
  }

  @override
  String get ledgerPayment => 'Payment';

  @override
  String ledgerPaidIn(String amount) {
    return 'Paid: $amount';
  }

  @override
  String get noEntries => 'No entries yet';

  @override
  String get paidNow => 'Paid now';

  @override
  String get remainingDebt => 'Remaining debt';

  @override
  String get customerLabel => 'Customer';

  @override
  String get chooseCustomer => 'Choose a customer';

  @override
  String get newCustomer => 'New customer';

  @override
  String get debtAtSale => 'Debt at sale';

  @override
  String get voidCreditNote =>
      'This is a credit invoice: the customer\'s balance will change when it is voided, and he may end up with a credit if he already paid.';

  @override
  String get payInCurrency => 'Pay in';

  @override
  String get settleDebtIn => 'Settle the debt in';

  @override
  String get debtLabel => 'Debt';

  @override
  String get paymentAmount => 'Amount paid';

  @override
  String appliedAmountLabel(String amount) {
    return 'Deducted from the debt: $amount';
  }

  @override
  String balanceAfter(String amount) {
    return 'Balance after the payment: $amount';
  }

  @override
  String get settleAll => 'Pay all';

  @override
  String get voidPayment => 'Void payment';

  @override
  String get voidPaymentConfirm =>
      'This payment will be cancelled and the debt returns as it was. It stays in the statement, struck through.';

  @override
  String get paymentVoided => 'Payment voided';

  @override
  String get hideCustomer => 'Hide customer';

  @override
  String get hideCustomerConfirm =>
      'This customer will disappear from the lists. His old invoices stay.';

  @override
  String get errCustomerHasDebt =>
      'A customer with a debt or a credit balance cannot be hidden';

  @override
  String get errPaymentExceedsDebt =>
      'The amount is more than the remaining debt';

  @override
  String get errNoDebt => 'The customer has no debt in this currency';

  @override
  String get suppliers => 'Suppliers';

  @override
  String get addSupplier => 'Add supplier';

  @override
  String get editSupplier => 'Edit supplier';

  @override
  String get supplierName => 'Supplier name';

  @override
  String get searchSuppliers => 'Search by name or phone';

  @override
  String get noSuppliers => 'No suppliers yet';

  @override
  String get newSupplier => 'New supplier';

  @override
  String get hideSupplier => 'Hide supplier';

  @override
  String get hideSupplierConfirm =>
      'This supplier will disappear from the lists. His old purchase invoices stay.';

  @override
  String get supplierLabel => 'Supplier';

  @override
  String get chooseSupplier => 'Choose a supplier';

  @override
  String get noSupplierSelected => 'No supplier selected';

  @override
  String get totalPayables => 'Total owed to suppliers';

  @override
  String get onlyWeOwe => 'Only those we owe';

  @override
  String get advanceWithSupplier => 'Advance with supplier';

  @override
  String get noPayable => 'Nothing owed';

  @override
  String get weOwe => 'We owe';

  @override
  String suppliersWithDebt(String count) {
    return 'Suppliers we owe: $count';
  }

  @override
  String statementSupplierHeader(String name) {
    return 'Supplier statement: $name';
  }

  @override
  String get statementWeOwe => 'Amount owed to the supplier';

  @override
  String get statementAdvance => 'Our advance with the supplier';

  @override
  String get statementNoPayable => 'Nothing is owed to the supplier.';

  @override
  String ledgerPurchase(String number) {
    return 'Purchase $number';
  }

  @override
  String get purchases => 'Purchases';

  @override
  String get newPurchase => 'New purchase invoice';

  @override
  String get purchasesHistory => 'Purchases history';

  @override
  String get purchaseDetails => 'Purchase invoice details';

  @override
  String get unitCostLabel => 'Unit cost';

  @override
  String get supplierInvoiceNumber => 'Supplier invoice number (optional)';

  @override
  String get purchaseDate => 'Purchase date';

  @override
  String get purchaseRate => 'Exchange rate for this invoice';

  @override
  String get updateCosts => 'Update product costs';

  @override
  String get updateCostsHint =>
      'Each product\'s cost becomes the unit cost on this invoice';

  @override
  String get addItems => 'Add items by searching or scanning a barcode';

  @override
  String get searchOrScanProduct => 'Search a product or scan its barcode';

  @override
  String get savePurchase => 'Save purchase invoice';

  @override
  String get purchaseSaved => 'Purchase invoice saved';

  @override
  String get continuousScanHintPurchase =>
      'Scan the items one after another (one unit per read), then go back';

  @override
  String get discardPurchase => 'Discard the current invoice?';

  @override
  String get discardPurchaseConfirm => 'The items you added will be lost.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discard => 'Discard';

  @override
  String previousCostLabel(String cost) {
    return 'Previous cost: $cost';
  }

  @override
  String costChange(String percent) {
    return 'Change: $percent';
  }

  @override
  String purchasesCount(String count) {
    return 'Invoices: $count';
  }

  @override
  String get totalPurchasesBase => 'Total purchases (base currency)';

  @override
  String get noPurchases => 'No purchase invoices on this day';

  @override
  String get voidPurchase => 'Void purchase invoice';

  @override
  String get voidPurchaseConfirm =>
      'The invoice quantities will be taken out of the stock (it may go below zero if the goods were sold). The previous product costs are not restored. This cannot be undone.';

  @override
  String get voidPurchaseCreditNote =>
      'This is a credit purchase: the supplier\'s balance will change when it is voided.';

  @override
  String get purchaseVoided => 'Purchase invoice voided';

  @override
  String get payableAtPurchase => 'Owed to the supplier at purchase';

  @override
  String get errSupplierRequired => 'Choose a supplier for a credit purchase';

  @override
  String get errSupplierHasDebt =>
      'A supplier we owe, or who holds an advance of ours, cannot be hidden';

  @override
  String get errNoPayable => 'Nothing is owed to the supplier in this currency';

  @override
  String get errEmptyPurchase => 'Add at least one item';

  @override
  String get backup => 'Backup';

  @override
  String get backupSubtitle => 'Export your data and restore it';

  @override
  String get exportBackup => 'Export a backup';

  @override
  String get restoreBackup => 'Restore from a file';

  @override
  String lastExport(String date) {
    return 'Last exported backup: $date';
  }

  @override
  String get neverExported => 'No backup has been exported yet';

  @override
  String exportOld(String days) {
    return '$days days since the last exported backup';
  }

  @override
  String get backupReminder => 'Save a backup of your data';

  @override
  String dbSize(String size) {
    return 'Data size: $size';
  }

  @override
  String get currentData => 'Current data';

  @override
  String get backupData => 'Backup data';

  @override
  String dataCounts(
    String products,
    String customers,
    String suppliers,
    String invoices,
  ) {
    return '$products products • $customers customers • $suppliers suppliers • $invoices sales invoices';
  }

  @override
  String lastInvoice(String date) {
    return 'Last invoice: $date';
  }

  @override
  String get noInvoicesYet => 'No invoices';

  @override
  String get autoBackup => 'Daily automatic backup';

  @override
  String get autoBackupHint =>
      'Keeps the last 7 copies inside the app, made when you open it each day. It does not replace exporting: these copies are deleted if the app is uninstalled or its data cleared.';

  @override
  String get internalBackups => 'Internal backups';

  @override
  String get noInternalBackups => 'No internal backups yet';

  @override
  String get backupAuto => 'Automatic';

  @override
  String get backupSafety => 'Safety copy before a restore';

  @override
  String get exportDialogTitle => 'Choose where to save the backup';

  @override
  String get exportDone => 'Backup saved';

  @override
  String get exportHint =>
      'Save the backup outside the app (Downloads or Google Drive). The file holds all your data, so keep it somewhere safe.';

  @override
  String get restoreConfirmTitle => 'Restore a backup?';

  @override
  String get restoreWarning =>
      'ALL your current data (products, invoices, customers, suppliers, settings and the exchange rate) will be replaced by the backup\'s data. A safety copy of your current data is saved first.';

  @override
  String get restoreDone => 'Restore complete';

  @override
  String get restoreDoneNote =>
      'Check the exchange rate in the settings: it went back to what the backup had. The app will reload now.';

  @override
  String get restore => 'Restore';

  @override
  String get export => 'Export';

  @override
  String get deleteBackupConfirm => 'Delete this backup?';

  @override
  String get errBackupNotSqlite => 'The chosen file is not a valid database';

  @override
  String get errBackupCorrupt => 'The file is damaged and cannot be restored';

  @override
  String get errBackupNotOurs => 'This file is not a backup of this app';

  @override
  String get errBackupNewerVersion =>
      'This backup is newer than the app. Update the app first';

  @override
  String get errBackupReadFailed => 'The file could not be read';

  @override
  String get errRestoreFailed =>
      'The restore failed, and your previous data was put back as it was';
}
