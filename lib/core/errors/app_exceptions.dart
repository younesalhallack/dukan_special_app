/// Business-rule errors raised by repositories. The UI maps each code to a
/// localized message with `errorMessage` (see error_messages.dart).
enum AppError {
  invalidName,
  invalidPrice,
  invalidQuantity,
  duplicateBarcode,
  duplicateCategory,
  negativeStock,
  notFound,
  emptyCart,
  invalidAmount,
  insufficientStock,
  alreadyVoided,
  customerRequired,
  customerHasDebt,
  paymentExceedsDebt,
  noDebt,
  supplierRequired,
  supplierHasDebt,
  noPayable,
  emptyPurchase,
}

/// Why a backup could not be read or restored.
enum BackupError {
  notSqlite,
  corrupt,
  notOurDatabase,
  newerVersion,
  readFailed,
  restoreFailed,
}

class BackupException implements Exception {
  const BackupException(this.error);

  final BackupError error;

  @override
  String toString() => 'BackupException(${error.name})';
}

class AppException implements Exception {
  const AppException(this.error);

  final AppError error;

  @override
  String toString() => 'AppException(${error.name})';
}
